#import <HBLog.h>

#import "Common.h"

#define IsNetworkTypeText(text) ( \
    [text isEqualToString:@"G"] || [text isEqualToString:@"3G"] || \
    [text isEqualToString:@"4G"] || [text isEqualToString:@"5G"] || \
    [text isEqualToString:@"LTE"])

static BOOL _isEnabled = NO;
static BOOL _isVPNEnabled = NO;
static BOOL _isEnabledReversed = NO;
static UIColor *_darkReplacementColor = nil;
static UIColor *_lightReplacementColor = nil;

static UIColor *smColorWithHexString(NSString *hexString) {
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if ([hexString hasPrefix:@"#"]) {
        [scanner setScanLocation:1];
    }

    unsigned int hexValue;
    if (![scanner scanHexInt:&hexValue]) {
        return nil;
    }

    CGFloat red = ((hexValue & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((hexValue & 0x00FF00) >> 8) / 255.0;
    CGFloat blue = (hexValue & 0x0000FF) / 255.0;

    return [UIColor colorWithRed:red green:green blue:blue alpha:1];
}

static UIColor *smColorWithTextColor(UIColor *textColor) {
    CGFloat red, green, blue, alpha;
    [textColor getRed:&red green:&green blue:&blue alpha:&alpha];
    BOOL isKindOfBlack = red < 0.5 && green < 0.5 && blue < 0.5;
    return isKindOfBlack ? _lightReplacementColor : _darkReplacementColor;
}

static void ReloadPrefs() {
    static NSUserDefaults *prefs = nil;
    if (!prefs) {
        prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.82flex.singlevpnprefs"];
    }

    NSDictionary *settings = [prefs dictionaryRepresentation];
    _isEnabled = settings[@"IsEnabled"] ? [settings[@"IsEnabled"] boolValue] : YES;
    _isEnabledReversed = settings[@"IsEnabledReversed"] ? [settings[@"IsEnabledReversed"] boolValue] : NO;
    
    if (settings[@"ForegroundColorLight"]) {
        _lightReplacementColor = smColorWithHexString(settings[@"ForegroundColorLight"]);
    } else {
        _lightReplacementColor = [UIColor colorWithRed:0.19607843137254902 green:0.7803921568627451 blue:0.34901960784313724 alpha:1];
    }

    if (settings[@"ForegroundColorDark"]) {
        _darkReplacementColor = smColorWithHexString(settings[@"ForegroundColorDark"]);
    } else {
        _darkReplacementColor = [UIColor colorWithRed:0.17254901960784313 green:0.8156862745098039 blue:0.3411764705882353 alpha:1];
    }
}

%group SingleVPN

%hook _UIStatusBarWifiItem

%property (nonatomic, strong) NSNumber *smIsVPNEnabled;
%property (nonatomic, strong) NSNumber *smDisplayValue;

- (id)applyUpdate:(_UIStatusBarItemUpdate *)update toDisplayItem:(_UIStatusBarDisplayItem *)displayItem {
    _isVPNEnabled = update.data.vpnEntry.enabled;
    long long displayValue = update.data.wifiEntry.displayValue;

    id result = %orig;
    BOOL needsReload = NO;

    if ([self.smIsVPNEnabled boolValue] != _isVPNEnabled) {
        self.smIsVPNEnabled = @(_isVPNEnabled);
        needsReload = YES;
    }

    if ([self.smDisplayValue longLongValue] != displayValue) {
        self.smDisplayValue = @(displayValue);
        needsReload = YES;
    }

    if (needsReload) {
        for (_UIStatusBarDisplayItem *item in self.displayItems.allValues) {
            %orig(update, item);
        }
    }

    return result;
}

- (UIColor *)_fillColorForUpdate:(_UIStatusBarItemUpdate *)update entry:(_UIStatusBarDataWifiEntry *)entry {
    BOOL decision = _isEnabledReversed ? !_isVPNEnabled : _isVPNEnabled;
    if (decision) { 
        return smColorWithTextColor(update.styleAttributes.textColor);
    } else {
        return %orig; 
    }
}

%end

%hook _UIStatusBarCellularItem

- (id)applyUpdate:(_UIStatusBarItemUpdate *)update toDisplayItem:(_UIStatusBarDisplayItem *)displayItem {
    _isVPNEnabled = update.data.vpnEntry.enabled;

    id result = %orig;

    UIColor *originalColor = update.styleAttributes.textColor;
    UIColor *newColor = nil;

    BOOL decision = _isEnabledReversed ? !_isVPNEnabled : _isVPNEnabled;
    if (decision) {
        newColor = smColorWithTextColor(originalColor);
    }

    if (!newColor) { newColor = originalColor; }

    for (_UIStatusBarDisplayItem *item in self.displayItems.allValues) {
        _UIStatusBarStringView *stringView = nil;

        if ([item.view isKindOfClass:%c(_UIStatusBarCellularNetworkTypeView)]) {
            stringView = ((_UIStatusBarCellularNetworkTypeView *)item.view).stringView;
        } else if ([item.view isKindOfClass:%c(_UIStatusBarStringView)]) {
            stringView = (_UIStatusBarStringView *)item.view;
        }

        if (IsNetworkTypeText(stringView.text)) {
            [stringView setTextColor:newColor];
        } else {
            [stringView setTextColor:originalColor];
        }
    }

    return result;
}

%end


%hook _UIStatusBarStringView

- (void)applyStyleAttributes:(_UIStatusBarStyleAttributes *)styleAttrs {
    %orig;

    BOOL decision = _isEnabledReversed ? !_isVPNEnabled : _isVPNEnabled;
    if (decision && IsNetworkTypeText(self.text)) {
        [self setTextColor:smColorWithTextColor(styleAttrs.textColor)];
    }
}

%end

%end // SingleVPN

%ctor {
    ReloadPrefs();
    if (!_isEnabled) {
        return;
    }

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), 
        NULL, 
        (CFNotificationCallback)ReloadPrefs, 
        CFSTR("com.82flex.singlevpnprefs/saved"), 
        NULL, 
        CFNotificationSuspensionBehaviorCoalesce
    );

    %init(SingleVPN);
}