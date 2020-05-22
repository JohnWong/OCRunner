//
//  ORTestWithObjc.m
//  OCRunnerTests
//
//  Created by Jiang on 2020/5/19.
//  Copyright © 2020 SilverFruity. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCRunner/OCRunner.h>
#import "ORStructDeclare.h"
@interface ORStructField: NSObject
@property (nonatomic,assign)void *fieldPointer;
@property (nonatomic,copy)NSString *fieldTypeEncode;
@end

@interface ORStructValue: NSObject
@property (nonatomic,assign) void *structPointer;
@property (nonatomic,strong) ORStructDeclare *decalre;
- (ORStructField *)fieldForKey:(NSString *)key;
- (instancetype)initWithPointer:(void *)pointer declare:(ORStructDeclare *)decl;
@end

@implementation ORStructField
- (BOOL)isStruct{
    NSString *ignorePointer = [self.fieldTypeEncode stringByReplacingOccurrencesOfString:@"^" withString:@""];
    return *ignorePointer.UTF8String == '{';
}
- (BOOL)isStructPointer{
    return [self isStruct] && (*self.fieldTypeEncode.UTF8String == '^');
}

- (ORStructField *)fieldForKey:(NSString *)key{
    NSCAssert([self isStruct], @"must be struct");
    NSString *structName = startStructNameDetect(self.fieldTypeEncode.UTF8String);
    ORStructDeclare *structDecl = [[ORStructDeclareTable shareInstance] getStructDeclareWithName:structName];
    ORStructValue *structValue = [[ORStructValue alloc] initWithPointer:self.fieldPointer declare:structDecl];
    return [structValue fieldForKey:key];;
}
- (ORStructField *)getPointerValueField{
    ORStructField *field = [ORStructField new];
    NSUInteger pointerCount = startDetectPointerCount(self.fieldTypeEncode.UTF8String);
    void *fieldPointer = self.fieldPointer;
    while (pointerCount != 0) {
        fieldPointer = *(void **)fieldPointer;
        pointerCount--;
    }
    field.fieldPointer = fieldPointer;
    field.fieldTypeEncode = startRemovePointerOfTypeEncode(self.fieldTypeEncode.UTF8String);
    return field;
}
@end


@implementation ORStructValue
- (instancetype)initWithPointer:(void *)pointer declare:(ORStructDeclare *)decl
{
    self = [super init];
    self.structPointer = pointer;
    self.decalre = decl;
    return self;
}
- (ORStructField *)fieldForKey:(NSString *)key{
    ORStructField *field = [ORStructField new];
    NSUInteger offset = self.decalre.keyOffsets[key].unsignedIntegerValue;
    field.fieldPointer = self.structPointer + offset;
    field.fieldTypeEncode = self.decalre.keyTypeEncodes[key];
    return field;
}
@end
@interface ORTestWithObjc : XCTestCase

@end

@implementation ORTestWithObjc

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    MFValue *value = [MFValue valueInstanceWithPointer:&CGRectMake];
    CGRect (*func)(CGFloat,CGFloat,CGFloat,CGFloat);
    func = value.pointerValue;
    CGRect a = (*func)(1,2,3,4);
    XCTAssert(a.origin.x == 1);
    XCTAssert(a.origin.y == 2);
    XCTAssert(a.size.width == 3);
    XCTAssert(a.size.height == 4);
}
typedef struct Element1Struct{
    int **a;
    int *b;
    CGFloat c;
}Element1Struct;
typedef struct Element2Struct{
    CGFloat x;
    CGFloat y;
    CGFloat z;
    Element1Struct t;
}Element2Struct;
typedef struct ContainerStruct{
    Element1Struct element1;
    Element1Struct *element1Pointer;
    Element2Struct element2;
    Element2Struct *element2Pointer;
}ContainerStruct;

Element1Struct *Element1StructMake(){
    Element1Struct *element = malloc(sizeof(Element1Struct));
    int *pointer1 = malloc(sizeof(int));
    *pointer1 = 100;
    element->a = malloc(sizeof(void *));
    *element->a = pointer1;
    element->b = pointer1;
    element->c = 101;
    return element;
}
Element2Struct *Element2StructMake(){
    Element2Struct *element = malloc(sizeof(Element2Struct));
    element->x = 1;
    element->y = 2;
    element->z = 3;
    element->t = *Element1StructMake();
    return element;
}
//FIXME: 结构体三级嵌套时，有问题. self.struct.frame.size.x 需要修改startStructDetect
- (void)testStructTypeEncodePairse{
    ORStructDeclare *decl = [ORStructDeclare structDecalre:@encode(CGPoint) keys:@[@"x",@"y"]];
    XCTAssertEqualObjects(decl.keySizes[@"x"], @(8));
    XCTAssertEqualObjects(decl.keySizes[@"y"], @(8));
    XCTAssertEqualObjects(decl.keyOffsets[@"x"], @(0));
    XCTAssertEqualObjects(decl.keyOffsets[@"y"], @(8));
    XCTAssertEqualObjects(decl.keyTypeEncodes[@"x"], @"d");
    XCTAssertEqualObjects(decl.keyTypeEncodes[@"y"], @"d");
}
- (void)testStructValueGet{
    CGRect rect = CGRectMake(1, 2, 3, 4);
    ORStructDeclare *rectDecl = [ORStructDeclare structDecalre:@encode(CGRect) keys:@[@"origin",@"size"]];
    ORStructDeclare *pointDecl = [ORStructDeclare structDecalre:@encode(CGPoint) keys:@[@"x",@"y"]];
    ORStructDeclare *sizeDecl = [ORStructDeclare structDecalre:@encode(CGSize) keys:@[@"width",@"height"]];
    
    [[ORStructDeclareTable shareInstance] addStructDeclare:rectDecl];
    [[ORStructDeclareTable shareInstance] addStructDeclare:pointDecl];
    [[ORStructDeclareTable shareInstance] addStructDeclare:sizeDecl];
    
    ORStructValue *rectValue = [[ORStructValue alloc] initWithPointer:&rect declare:rectDecl];
    CGFloat x = *(CGFloat *)[[rectValue fieldForKey:@"origin"] fieldForKey:@"x"].fieldPointer;
    CGFloat y = *(CGFloat *)[[rectValue fieldForKey:@"origin"] fieldForKey:@"y"].fieldPointer;
    CGFloat width = *(CGFloat *)[[rectValue fieldForKey:@"size"] fieldForKey:@"width"].fieldPointer;
    CGFloat height = *(CGFloat *)[[rectValue fieldForKey:@"size"] fieldForKey:@"height"].fieldPointer;
    XCTAssert(x == 1);
    XCTAssert(y == 2);
    XCTAssert(width == 3);
    XCTAssert(height == 4);
}
- (void)testStructValueMultiLevelGet{
    ContainerStruct container;
    Element1Struct *element1 = Element1StructMake();
    Element2Struct *element2 = Element2StructMake();
    container.element1 = *element1;
    container.element1Pointer = element1;
    container.element2 = *element2;
    container.element2Pointer = element2;

    ORStructDeclare *element1Decl = [ORStructDeclare structDecalre:@encode(Element1Struct) keys:@[@"a",@"b",@"c"]];
    ORStructDeclare *element2Decl = [ORStructDeclare structDecalre:@encode(Element2Struct) keys:@[@"x",@"y",@"z",@"t"]];
    ORStructDeclare *containerDecl = [ORStructDeclare structDecalre:@encode(ContainerStruct) keys:@[@"element1",@"element1Pointer",@"element2",@"element2Pointer"]];
    
    [[ORStructDeclareTable shareInstance] addStructDeclare:element1Decl];
    [[ORStructDeclareTable shareInstance] addStructDeclare:element2Decl];
    [[ORStructDeclareTable shareInstance] addStructDeclare:containerDecl];
    
    ORStructValue *containerValue = [[ORStructValue alloc] initWithPointer:&container declare:containerDecl];
    CGFloat c3 = *(CGFloat *)[[[containerValue fieldForKey:@"element2"] fieldForKey:@"t"] fieldForKey:@"c"].fieldPointer;
    XCTAssert(c3 == 101);
    CGFloat pC3 = *(CGFloat *)[[[[containerValue fieldForKey:@"element2Pointer"] getPointerValueField] fieldForKey:@"t"] fieldForKey:@"c"].fieldPointer;
    XCTAssert(pC3 == 101);
    int p1b = *(int *)[[[containerValue fieldForKey:@"element1"] fieldForKey:@"b"] getPointerValueField].fieldPointer;
    XCTAssert(p1b == 100);
    int p2a = *(int *)[[[containerValue fieldForKey:@"element1"] fieldForKey:@"a"] getPointerValueField].fieldPointer;
    XCTAssert(p2a == 100);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
