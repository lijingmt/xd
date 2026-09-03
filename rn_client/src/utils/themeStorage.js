/** 可注入存储后端（TestUnit 用内存 Map，运行时用 AsyncStorage）。 */

let injectedBackend = null;

export function injectableStorage() {
  if (injectedBackend) return Promise.resolve(injectedBackend);
  return import('@react-native-async-storage/async-storage')
    .then(module => module.default);
}

export function setThemeStorageBackend(backend) {
  injectedBackend = backend;
}
