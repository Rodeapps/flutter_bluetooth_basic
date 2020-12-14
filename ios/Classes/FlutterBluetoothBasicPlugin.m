#import "FlutterBluetoothBasicPlugin.h"
#import "ConnecterManager.h"

API_AVAILABLE(ios(5.0))
@interface FlutterBluetoothBasicPlugin ()
@property(nonatomic, retain) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, retain) FlutterMethodChannel *channel;
@property(nonatomic, retain) BluetoothPrintStreamHandler *stateStreamHandler;
@property(nonatomic) NSMutableDictionary *scannedPeripherals;
@property(nonatomic,retain)CBCentralManager *centralManager;

@end

@implementation FlutterBluetoothBasicPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:NAMESPACE @"/methods"
                                     binaryMessenger:[registrar messenger]];
    FlutterEventChannel* stateChannel = [FlutterEventChannel eventChannelWithName:NAMESPACE @"/state" binaryMessenger:[registrar messenger]];
    FlutterBluetoothBasicPlugin* instance = [[FlutterBluetoothBasicPlugin alloc] init];
    
    instance.centralManager = [CBCentralManager new];
    instance.centralManager.delegate = instance;
    
    instance.channel = channel;
    instance.scannedPeripherals = [NSMutableDictionary new];
    
    // STATE
    BluetoothPrintStreamHandler* stateStreamHandler = [[BluetoothPrintStreamHandler alloc] init];
    [stateChannel setStreamHandler:stateStreamHandler];
    instance.stateStreamHandler = stateStreamHandler;
    [Manager didUpdateState:^(NSInteger state) {
        switch (state) {
            case CBCentralManagerStateUnsupported:
            case CBCentralManagerStateUnauthorized:
            case CBCentralManagerStatePoweredOff:
                if(instance.stateStreamHandler.sink!= nil) {
                    //10 - status value for bluetooth powered on
                    instance.stateStreamHandler.sink(@10);
                }
                break;
            case CBCentralManagerStatePoweredOn:
                if(instance.stateStreamHandler.sink!= nil) {
                    //12 - status value for bluetooth poweren on
                    instance.stateStreamHandler.sink(@12);
                }
                break;
            case CBCentralManagerStateUnknown:
            default:
                break;
        }
    }];
    [registrar addMethodCallDelegate:instance channel:channel];
    NSLog(@"REGISTRAR");
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSLog(@"INIT");
        
    }
    return self;
}


- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSLog(@"call method -> %@", call.method);
    
    if ([@"state" isEqualToString:call.method]) {
        
        
        result(nil);
    } else if([@"isAvailable" isEqualToString:call.method]) {
        
        result(@(YES));
    } else if([@"isConnected" isEqualToString:call.method]) {
        
        result(@(NO));
    } else if([@"isOn" isEqualToString:call.method]) {
        result(@(YES));
    }else if([@"startScan" isEqualToString:call.method]) {
        NSLog(@"getDevices method -> %@", call.method);
        [self.scannedPeripherals removeAllObjects];
        
        if (Manager.bleConnecter == nil) {
            [Manager didUpdateState:^(NSInteger state) {
                switch (state) {
                    case CBCentralManagerStateUnsupported:
                        NSLog(@"The platform/hardware doesn't support Bluetooth Low Energy.");
                        break;
                    case CBCentralManagerStateUnauthorized:
                        NSLog(@"The app is not authorized to use Bluetooth Low Energy.");
                        break;
                    case CBCentralManagerStatePoweredOff:
                        NSLog(@"Bluetooth is currently powered off.");
                        break;
                    case CBCentralManagerStatePoweredOn:
                        [self startScan];
                        NSLog(@"Bluetooth power on");
                        break;
                    case CBCentralManagerStateUnknown:
                    default:
                        break;
                }
            }];
        } else {
            [self startScan];
        }
        
        result(nil);
    } else if([@"stopScan" isEqualToString:call.method]) {
        [Manager stopScan];
        result(nil);
    } else if([@"connect" isEqualToString:call.method]) {
        NSDictionary *device = [call arguments];
        @try {
            NSLog(@"connect device begin -> %@", [device objectForKey:@"name"]);
            CBPeripheral *peripheral = [_scannedPeripherals objectForKey:[device objectForKey:@"address"]];
            
            self.state = ^(ConnectState state) {
                [self updateConnectState:state];
            };
            
            [_centralManager connectPeripheral:peripheral options:nil];
//            [Manager connectPeripheral:peripheral options:nil timeout:2 connectBlack: self.state];
            
            result(nil);
        } @catch(FlutterError *e) {
            result(e);
        }
    } else if([@"disconnect" isEqualToString:call.method]) {
        @try {
            [Manager close];
            result(nil);
        } @catch(FlutterError *e) {
            result(e);
        }
    } else if([@"writeData" isEqualToString:call.method]) {
        @try {
            NSDictionary *args = [call arguments];
            
            NSMutableArray *bytes = [args objectForKey:@"bytes"];
            
            NSNumber* lenBuf = [args objectForKey:@"length"];
            int len = [lenBuf intValue];
            char cArray[len];
            
            for (int i = 0; i < len; ++i) {
                //               NSLog(@"** ind_%d (d): %@, %d", i, bytes[i], [bytes[i] charValue]);
                cArray[i] = [bytes[i] charValue];
            }
            NSData *data2 = [NSData dataWithBytes:cArray length:sizeof(cArray)];
            //           NSLog(@"bytes in hex: %@", [data2 description]);
            [Manager write:data2];
            result(nil);
        } @catch(FlutterError *e) {
            result(e);
        }
    }
}

-(void)startScan {
    if (@available(iOS 5.0, *)) {
        [centralManager scanForPeripheralsWithServices:nil options:nil];
    } else {
        // Fallback on earlier versions
        if (@available(iOS 5.0, *)) {
            [Manager scanForPeripheralsWithServices:nil options:nil discover:^(CBPeripheral * _Nullable peripheral, NSDictionary<NSString *,id> * _Nullable advertisementData, NSNumber * _Nullable RSSI) {
                if (peripheral.name != nil) {
                    
                    NSLog(@"find device -> %@", peripheral.name);
                    [self.scannedPeripherals setObject:peripheral forKey:[[peripheral identifier] UUIDString]];
                    
                    NSDictionary *device = [NSDictionary dictionaryWithObjectsAndKeys:peripheral.identifier.UUIDString,@"address",peripheral.name,@"name",nil,@"type",nil];
                    [_channel invokeMethod:@"ScanResult" arguments:device];
                }
            }];
        } else {
            // Fallback on earlier versions
        }
        
    }
   
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI  API_AVAILABLE(ios(5.0)){
    
    NSLog(@"scanned and found this peripheral: %@", peripheral);
    NSLog(@"advertisment data: %@", advertisementData);
    
    
    NSLog(@"\n");
    NSLog(@"-------------------------------------------");
    NSLog(@"DC peripheral found!  %@", peripheral);
    
    peripheral.delegate = self;
    if (peripheral.name != nil) {
        
        NSLog(@"find device -> %@", peripheral.name);
        if (@available(iOS 7.0, *)) {
            [self.scannedPeripherals setObject:peripheral forKey:[[peripheral identifier] UUIDString]];
        } else {
            // Fallback on earlier versions
        }
        
        if (@available(iOS 7.0, *)) {
            NSDictionary *device = [NSDictionary dictionaryWithObjectsAndKeys:peripheral.identifier.UUIDString,@"address",peripheral.name,@"name",nil,@"type",nil];
            [_channel invokeMethod:@"ScanResult" arguments:device];
        } else {
            // Fallback on earlier versions
        }
    }
    NSLog(@"-------------------------------------------");
    NSLog(@"\n");
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    NSLog(@"-----------centralManagerDidUpdateState----------------------");
}




-(void)updateConnectState:(ConnectState)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNumber *ret = @0;
        switch (state) {
            case CONNECT_STATE_CONNECTING:
                NSLog(@"status -> %@", @"Connecting ...");
                ret = @0;
                break;
            case CONNECT_STATE_CONNECTED:
                NSLog(@"status -> %@", @"Connection success");
                ret = @1;
                break;
            case CONNECT_STATE_FAILT:
                NSLog(@"status -> %@", @"Connection failed");
                ret = @0;
                break;
            case CONNECT_STATE_DISCONNECT:
                NSLog(@"status -> %@", @"Disconnected");
                ret = @0;
                break;
            default:
                NSLog(@"status -> %@", @"Connection timed out");
                ret = @0;
                break;
        }
        
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:ret,@"id",nil];
        if(self->_stateStreamHandler.sink != nil) {
            self.stateStreamHandler.sink([dict objectForKey:@"id"]);
        }
    });
}

@end

@implementation BluetoothPrintStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    self.sink = eventSink;
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    self.sink = nil;
    return nil;
}

@end
