//#region src/stage.d.ts
type StageDefinition = {
  x: number;
  y: number;
  width: number;
  height: number;
};
//#endregion
//#region src/context.d.ts
type HookOpts = {
  config: Config;
  state: State;
  driver: Driver;
  index: number | undefined;
};
type DriverHook = (element: Element | undefined, step: DriveStep, opts: HookOpts) => void;
type Config = {
  steps?: DriveStep[];
  animate?: boolean;
  duration?: number;
  overlayColor?: string;
  overlayOpacity?: number;
  smoothScroll?: boolean;
  allowClose?: boolean;
  allowScroll?: boolean;
  overlayClickBehavior?: "close" | "nextStep" | DriverHook;
  stagePadding?: number;
  stageRadius?: number;
  disableActiveInteraction?: boolean;
  advanceOnClick?: boolean;
  skipMissingElement?: boolean;
  waitForElement?: number;
  allowKeyboardControl?: boolean;
  popoverClass?: string;
  popoverOffset?: number;
  showButtons?: AllowedButtons[];
  disableButtons?: AllowedButtons[];
  showProgress?: boolean;
  progressText?: string;
  nextBtnText?: string;
  prevBtnText?: string;
  doneBtnText?: string;
  onPopoverRender?: (popover: PopoverDOM, opts: HookOpts) => void;
  onHighlightStarted?: DriverHook;
  onHighlighted?: DriverHook;
  onDeselected?: DriverHook;
  onDestroyStarted?: DriverHook;
  onDestroyed?: DriverHook;
  onNextClick?: DriverHook;
  onPrevClick?: DriverHook;
  onCloseClick?: DriverHook;
  onDoneClick?: DriverHook;
};
type State = {
  isInitialized?: boolean;
  activeIndex?: number;
  activeElement?: Element;
  activeStep?: DriveStep;
  previousElement?: Element;
  previousStep?: DriveStep;
  popover?: PopoverDOM;
  __previousElement?: Element;
  __activeElement?: Element;
  __previousStep?: DriveStep;
  __activeStep?: DriveStep;
  __activeOnDestroyed?: Element;
  __resizeTimeout?: number;
  __transitionCallback?: () => void;
  __pendingWaitCancel?: () => void;
  __activeStagePosition?: StageDefinition;
  __overlaySvg?: SVGSVGElement;
  __events?: {
    onKeyup: (e: KeyboardEvent) => void;
    onKeydown: (e: KeyboardEvent) => void;
    onResize: () => void;
    onScroll: () => void;
    onClick: (e: MouseEvent) => void;
  };
};
//#endregion
//#region src/popover.d.ts
type Side = "top" | "right" | "bottom" | "left";
type Alignment = "start" | "center" | "end";
type AllowedButtons = "next" | "previous" | "close";
type Popover = {
  title?: string;
  description?: string;
  side?: Side;
  align?: Alignment;
  showButtons?: AllowedButtons[];
  showProgress?: boolean;
  disableButtons?: AllowedButtons[];
  popoverClass?: string;
  progressText?: string;
  doneBtnText?: string;
  nextBtnText?: string;
  prevBtnText?: string;
  onPopoverRender?: (popover: PopoverDOM, opts: HookOpts) => void;
  onNextClick?: DriverHook;
  onPrevClick?: DriverHook;
  onCloseClick?: DriverHook;
  onDoneClick?: DriverHook;
};
type PopoverDOM = {
  wrapper: HTMLElement;
  arrow: HTMLElement;
  title: HTMLElement;
  description: HTMLElement;
  footer: HTMLElement;
  progress: HTMLElement;
  previousButton: HTMLButtonElement;
  nextButton: HTMLButtonElement;
  closeButton: HTMLButtonElement;
  footerButtons: HTMLElement;
};
//#endregion
//#region src/driver.d.ts
type DriveStep = {
  element?: string | Element | (() => Element);
  onHighlightStarted?: DriverHook;
  onHighlighted?: DriverHook;
  onDeselected?: DriverHook;
  popover?: Popover;
  disableActiveInteraction?: boolean;
  advanceOnClick?: boolean;
  skipMissingElement?: boolean;
  waitForElement?: number;
  data?: Record<string, any>;
};
interface Driver {
  isActive: () => boolean;
  refresh: () => void;
  drive: (stepIndex?: number) => void;
  setConfig: (config: Config) => void;
  setSteps: (steps: DriveStep[]) => void;
  getConfig: () => Config;
  getState: (key?: string) => any;
  getActiveIndex: () => number | undefined;
  isFirstStep: () => boolean;
  isLastStep: () => boolean;
  getActiveStep: () => DriveStep | undefined;
  getActiveElement: () => Element | undefined;
  getPreviousElement: () => Element | undefined;
  getPreviousStep: () => DriveStep | undefined;
  getNextStep: () => DriveStep | undefined;
  moveNext: () => void;
  movePrevious: () => void;
  moveTo: (index: number) => void;
  hasNextStep: () => boolean;
  hasPreviousStep: () => boolean;
  highlight: (step: DriveStep) => void;
  destroy: () => void;
}
declare function driver(options?: Config): Driver;
//#endregion
export { type Alignment, type AllowedButtons, type Config, DriveStep, Driver, type DriverHook, type Popover, type PopoverDOM, type Side, type StageDefinition, type State, driver };