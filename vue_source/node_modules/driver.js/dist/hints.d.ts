//#region src/popover.d.ts
type Side = "top" | "right" | "bottom" | "left";
type Alignment = "start" | "center" | "end";
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
//#region src/hints.d.ts
type HintBeacon = {
  side?: Side;
  align?: Alignment;
  animate?: boolean;
  className?: string;
};
type HintPopover = {
  title?: string;
  description?: string;
  side?: Side;
  align?: Alignment;
  popoverClass?: string;
  showButton?: boolean;
  buttonText?: string;
  onButtonClick?: HintHook;
  onPopoverRender?: (popover: PopoverDOM, opts: {
    hint: DriverHint;
    hints: Hints;
  }) => void;
};
type HintHook = (element: Element, hint: DriverHint, opts: {
  config: HintsConfig;
  hints: Hints;
}) => void;
type DriverHint = {
  element: string | Element | (() => Element);
  id?: string;
  beacon?: HintBeacon;
  popover?: HintPopover;
  onOpen?: HintHook;
  onDismiss?: HintHook;
  data?: Record<string, any>;
};
type HintsConfig = {
  hints?: DriverHint[];
  beacon?: HintBeacon;
  buttonText?: string;
  popoverClass?: string;
  popoverOffset?: number;
  overlay?: boolean;
  overlayColor?: string;
  overlayOpacity?: number;
  onOpen?: HintHook;
  onDismiss?: HintHook;
  onButtonClick?: HintHook;
};
interface Hints {
  show: () => void;
  hide: () => void;
  open: (id: string | number) => void;
  close: () => void;
  dismiss: (id: string | number) => void;
  restore: (id: string | number) => void;
  setHints: (hints: DriverHint[]) => void;
  getHints: () => DriverHint[];
  getActive: () => DriverHint | undefined;
  isVisible: () => boolean;
  refresh: () => void;
}
declare function hints(config?: HintsConfig): Hints;
//#endregion
export { type Alignment, DriverHint, HintBeacon, HintHook, HintPopover, Hints, HintsConfig, type PopoverDOM, type Side, hints };