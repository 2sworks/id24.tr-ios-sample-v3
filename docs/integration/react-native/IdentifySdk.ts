//
//  IdentifySdk.ts
//  React Native sarmalayıcı — IdentifySDK
//
//  Native köprüyü (IdentifySdkModule) tip-güvenli bir API ile sarar ve birleşik
//  olay akışını (SDKEvent) JS tarafında dinlemeyi sağlar.
//

import {
  NativeModules,
  NativeEventEmitter,
  EmitterSubscription,
} from 'react-native';

const { IdentifySdkModule } = NativeModules;
const emitter = new NativeEventEmitter(IdentifySdkModule);

// MARK: - Olay tipleri (native SDKEvent.toDictionary() ile birebir)

export type SDKEventCategory =
  | 'session'
  | 'module'
  | 'call'
  | 'network'
  | 'error'
  | 'navigation';

export type SDKEventStatus =
  | 'info'
  | 'presented'
  | 'completed'
  | 'failed'
  | 'skipped'
  | 'success'
  | 'abandoned'
  | 'notFound';

export interface SDKEvent {
  /** "session.started", "module.Selfie.completed", "call.ended" ... */
  name: string;
  category: SDKEventCategory;
  status: SDKEventStatus;
  /** İlgili modül (SdkModules rawValue), session/call'da olmayabilir. */
  module?: string;
  /** Kullanıcının o anki / son ekranı. */
  screen?: string;
  sessionId: string;
  timestampMs: number;
  message?: string;
  /** reason, statusSummary, lastScreen ... */
  metadata: Record<string, string>;
}

// MARK: - setupSDK parametreleri

export interface SetupOptions {
  identId: string;
  baseApiUrl: string;
  turnKey: string;
  signLangSupport?: boolean;
  nfcMaxErrorCount?: number;
  /** SdkModules rawValue listesi; boş = backend sırası. */
  selectedModules?: string[];
  wsSecretKey?: string;
  showThankYouPage?: boolean;
  showNFCNotFoundPage?: boolean;
  supportU18?: boolean;
}

// MARK: - Public API

export const IdentifySdk = {
  /** SDK'yı başlatır. Çözülürse { result } döner. */
  setupSDK(options: SetupOptions): Promise<{ result: boolean }> {
    return IdentifySdkModule.setupSDK(options);
  },

  /** Birleşik olay akışına abone olur. `subscription.remove()` ile bırakılır. */
  addEventListener(handler: (event: SDKEvent) => void): EmitterSubscription {
    return emitter.addListener('onSDKEvent', handler);
  },

  /**
   * SDK'nın hazır ekranlarının temasını uygular. Native derleme GEREKMEZ —
   * JS reload yeterlidir, bu yüzden renk/logo denemesi saniyeler sürer.
   *
   * Renk değeri "#RRGGBB" ya da { light, dark } olabilir; köşe "capsule" ya da sayıdır.
   * Dönen `unknownKeys` yazım hatası olan anahtarları listeler.
   */
  setTheme(theme: SDKThemeConfig): Promise<{ result: boolean; unknownKeys: string[] }> {
    return IdentifySdkModule.setTheme(theme);
  },

  /** Tüm görünüm override'larını siler (SDK varsayılanlarına döner). */
  resetTheme(): void {
    IdentifySdkModule.resetTheme();
  },

  /** Kullanıcı SDK'yı açıkça kapatınca terk olayı tetiklemek için. */
  reportAbandoned(reason?: string): void {
    IdentifySdkModule.reportAbandoned(reason ?? null);
  },
};

// MARK: - Tema tipleri

/** "#RRGGBB" ya da açık/koyu tema için ayrı değerler. */
export type SDKColorValue = string | { light?: string; dark?: string };
/** "capsule" (tam yuvarlak) ya da köşe yarıçapı. */
export type SDKCornerValue = 'capsule' | number;
export type SDKFontValue = { size: number; weight?: SDKFontWeight };
export type SDKFontWeight =
  | 'ultraLight' | 'thin' | 'light' | 'regular'
  | 'medium' | 'semibold' | 'bold' | 'heavy' | 'black';

export interface SDKButtonThemeConfig {
  corner?: SDKCornerValue;
  height?: number;
  verticalPadding?: number;
  horizontalPadding?: number;
  font?: SDKFontValue;
  background?: string;
  foreground?: string;
  borderWidth?: number;
  borderColor?: string;
  shadowColor?: string;
  shadowRadius?: number;
  shadowOffsetY?: number;
  disabledOpacity?: number;
  pressedScale?: number;
  hapticsEnabled?: boolean;
  fullWidth?: boolean;
}

export interface SDKThemeConfig {
  colors?: {
    // Marka paleti
    primary?: SDKColorValue; primaryDark?: SDKColorValue; primaryLight?: SDKColorValue;
    success?: SDKColorValue; successBright?: SDKColorValue; error?: SDKColorValue;
    accentWarning?: SDKColorValue; divider?: SDKColorValue;
    // Rol renkleri (light/dark ayrı verilebilir)
    pageBackground?: SDKColorValue; moduleBackground?: SDKColorValue; surface?: SDKColorValue;
    title?: SDKColorValue; subtitle?: SDKColorValue; border?: SDKColorValue;
    headerBackground?: SDKColorValue; headerTitle?: SDKColorValue; headerSubtitle?: SDKColorValue;
    headerIcon?: SDKColorValue; headerIconBackground?: SDKColorValue; headerIconBorder?: SDKColorValue;
    progressActive?: SDKColorValue; progressInactive?: SDKColorValue;
    selectedItemBackground?: SDKColorValue; selectedItemText?: SDKColorValue;
    unselectedItemBackground?: SDKColorValue; unselectedItemText?: SDKColorValue;
    [key: string]: SDKColorValue | undefined;
  };
  fonts?: { family?: string | null };
  metrics?: { [key: string]: number };
  buttons?: SDKButtonThemeConfig & {
    styles?: Partial<Record<'primary' | 'cancel' | 'secondary' | 'success', SDKButtonThemeConfig>>;
  };
  navBar?: {
    /** Hazır başlık tasarımı. */
    preset?: 'classic' | 'centered' | 'minimal' | 'prominent';
    height?: number; showsLogo?: boolean; logoSize?: number;
    circleButtonSize?: number; iconSize?: number;
    titleFont?: SDKFontValue; subtitleFont?: SDKFontValue;
    progressHeight?: number; progressSpacing?: number; progressCorner?: SDKCornerValue;
    overlayGradientOpacity?: number; showsDivider?: boolean;
  };
  selection?: {
    cornerRadius?: number; rowMinHeight?: number; checkboxSize?: number;
    checkboxCornerRadius?: number; radioDotSize?: number; checkmarkColor?: string;
  };
  alerts?: {
    cornerRadius?: number; maxWidth?: number; shadowRadius?: number; shadowOffsetY?: number;
    scrimOpacity?: number; iconCircleSize?: number; iconCircleOpacity?: number; showsDivider?: boolean;
  };
  banners?: {
    cornerRadius?: number; shadowRadius?: number; shadowOffsetY?: number;
    iconCircleSize?: number; iconCircleOpacity?: number;
  };
  fields?: {
    cornerRadius?: number; background?: SDKColorValue; borderColor?: SDKColorValue;
    borderWidth?: number; placeholderColor?: SDKColorValue; minHeight?: number;
  };
  sheets?: {
    cornerRadius?: number; handleWidth?: number; handleHeight?: number;
    handleColor?: SDKColorValue; background?: SDKColorValue;
  };
  capture?: {
    maskOpacity?: number; guideStrokeColor?: string; guideLockedColor?: string;
    guideLineWidth?: number; faceAlignedColor?: string; faceIdleColor?: string;
    overlayButtonFill?: string; overlayButtonBorder?: string;
  };
  controls?: {
    shutterSize?: number; shutterRingWidth?: number; shutterFill?: string;
    shutterRingColor?: string; recordingColor?: string; progressRingWidth?: number;
  };
  call?: {
    panelCornerRadius?: number; panelBackground?: string; handleColor?: string;
    controlSize?: number; remoteVideoBackground?: string; localPreviewCornerRadius?: number;
  };
  motion?: { transitionDuration?: number; overlayDuration?: number; disabled?: boolean };
  /** Değer, HOST uygulamasının asset kataloğundaki görsel adıdır. */
  icons?: { headerLogo?: string; logo?: string; hamburger?: string; [key: string]: string | undefined };
}

// Bilinen olay adları (switch'lerde tip yardımı için).
export const SDKEventName = {
  sessionStarted: 'session.started',
  sessionCompleted: 'session.completed',
  sessionFailed: 'session.failed',
  sessionAbandoned: 'session.abandoned',
  callConnected: 'call.connected',
  callEnded: 'call.ended',
} as const;
