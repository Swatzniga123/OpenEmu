/*
 Copyright (c) 2009, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "HIDManager.h"
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDUsageTables.h>


@implementation HIDManager

#define DEADZONE_PERCENT (25)

static void
Handle_InputValueCallback(
						  void* inContext,
						  IOReturn inResult,
						  void* inSender,
						  IOHIDValueRef inIOHIDValueRef )
{
	
	
}


// this will be called when a HID device is removed ( unplugged )
static void Handle_RemovalCallback(
								   void *         inContext,       // context from IOHIDManagerRegisterDeviceMatchingCallback
								   IOReturn       inResult,        // the result of the removing operation
								   void *         inSender,        // the IOHIDManagerRef for the device being removed
								   IOHIDDeviceRef inIOHIDDeviceRef // the removed HID device
)
{
	printf( "%s( context: %p, result: %p, sender: %p, device: %p ).\n",
		   __PRETTY_FUNCTION__, inContext, ( void * ) inResult, inSender, ( void* ) inIOHIDDeviceRef );
	
	// Should unregister from the input value callback here
	
}   // Handle_RemovalCallback

static void
Handle_DeviceMatchingCallback(
							  void* inContext,
							  IOReturn inResult,
							  void* inSender,
							  IOHIDDeviceRef inIOHIDDeviceRef )
{
	NSLog(@"Found device");
	printf( "%s( context: %p, result: %p, sender: %p, device: %p ).\n",        __PRETTY_FUNCTION__, inContext, ( void * ) inResult, inSender, ( void* ) inIOHIDDeviceRef );
	
	if (IOHIDDeviceOpen(inIOHIDDeviceRef, kIOHIDOptionsTypeNone) != kIOReturnSuccess)
	{
		printf( "%s: failed to open device at %p\n", __PRETTY_FUNCTION__, (void*)inIOHIDDeviceRef );
		return;
	}
	
	NSLog(@"%@",IOHIDDeviceGetProperty( inIOHIDDeviceRef, CFSTR( kIOHIDProductKey ) ));
	
	//IOHIDDeviceRegisterRemovalCallback(inIOHIDDeviceRef, Handle_RemovalCallback, inContext);
	    
	IOHIDDeviceRegisterInputValueCallback(
										  inIOHIDDeviceRef,
										  Handle_InputValueCallback,
										  inContext);
	
	IOHIDDeviceScheduleWithRunLoop(
								   inIOHIDDeviceRef,
								   CFRunLoopGetCurrent(),
								   kCFRunLoopDefaultMode );
	
}   // Handle_DeviceMatchingCallback

// function to create matching dictionary
static CFMutableDictionaryRef hu_CreateDeviceMatchingDictionary( UInt32 inUsagePage, UInt32 inUsage )
{
    // create a dictionary to add usage page/usages to
    CFMutableDictionaryRef result = CFDictionaryCreateMutable(
															  kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks );
    if ( result ) {
        if ( inUsagePage ) {
            // Add key for device type to refine the matching dictionary.
            CFNumberRef pageCFNumberRef = CFNumberCreate(
														 kCFAllocatorDefault, kCFNumberIntType, &inUsagePage );
            if ( pageCFNumberRef ) {
                CFDictionarySetValue( result,
									 CFSTR( kIOHIDDeviceUsagePageKey ), pageCFNumberRef );
                CFRelease( pageCFNumberRef );
				
                // note: the usage is only valid if the usage page is also defined
                if ( inUsage ) {
                    CFNumberRef usageCFNumberRef = CFNumberCreate(
																  kCFAllocatorDefault, kCFNumberIntType, &inUsage );
                    if ( usageCFNumberRef ) {
                        CFDictionarySetValue( result,
											 CFSTR( kIOHIDDeviceUsageKey ), usageCFNumberRef );
                        CFRelease( usageCFNumberRef );
                    } else {
                        fprintf( stderr, "%s: CFNumberCreate( usage ) failed.", __PRETTY_FUNCTION__ );
                    }
                }
            } else {
                fprintf( stderr, "%s: CFNumberCreate( usage page ) failed.", __PRETTY_FUNCTION__ );
            }
        }
    } else {
        fprintf( stderr, "%s: CFDictionaryCreateMutable failed.", __PRETTY_FUNCTION__ );
    }
    return result;
}   // hu_CreateDeviceMatchingDictionary

- (id) init
{
	self = [super init];
	
	if(self)
	{
		IOHIDManagerRef hidManager = NULL;
		
		
		hidManager = IOHIDManagerCreate( kCFAllocatorDefault, kIOHIDOptionsTypeNone );
		
		CFArrayRef matchingCFArrayRef = CFArrayCreateMutable( kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );
		
		if ( matchingCFArrayRef ) {
			// create a device matching dictionary for joysticks
			CFDictionaryRef matchingCFDictRef =
			hu_CreateDeviceMatchingDictionary( kHIDPage_GenericDesktop, kHIDUsage_GD_Joystick );
			if ( matchingCFDictRef ) {
				// add it to the matching array
				CFArrayAppendValue( matchingCFArrayRef, matchingCFDictRef );
				CFRelease( matchingCFDictRef ); // and release it
			} else {
				fprintf( stderr, "%s: hu_CreateDeviceMatchingDictionary( joystick ) failed.", __PRETTY_FUNCTION__ );
			}
			
			// create a device matching dictionary for game pads
			matchingCFDictRef = hu_CreateDeviceMatchingDictionary( kHIDPage_GenericDesktop, kHIDUsage_GD_GamePad );
			if ( matchingCFDictRef ) {
				// add it to the matching array
				CFArrayAppendValue( matchingCFArrayRef, matchingCFDictRef );
				CFRelease( matchingCFDictRef ); // and release it
			} else {
				fprintf( stderr, "%s: hu_CreateDeviceMatchingDictionary( game pad ) failed.", __PRETTY_FUNCTION__ );
			}
		} else {
			fprintf( stderr, "%s: CFArrayCreateMutable failed.", __PRETTY_FUNCTION__ );
		}
		
		IOHIDManagerSetDeviceMatchingMultiple( hidManager, matchingCFArrayRef );
		
		CFRelease( matchingCFArrayRef );
		
		
		
		IOHIDManagerRegisterDeviceMatchingCallback(
												   hidManager,
												   Handle_DeviceMatchingCallback,
												   self );
		
		
		IOHIDManagerScheduleWithRunLoop(
										hidManager,
										CFRunLoopGetCurrent(),
										kCFRunLoopDefaultMode );
		
		
	}
	return self;
}

@end
