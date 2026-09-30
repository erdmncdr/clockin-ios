'use strict';
// Apply a saved appearance before the first paint. Language defaults to English.
(() => {
  const read = key => {try{return localStorage.getItem(key);}catch{return null;}};
  const write = (key,value) => {try{localStorage.setItem(key,value);}catch{/* Preferences remain active for this visit. */}};
  const system = matchMedia('(prefers-color-scheme: dark)');
  let theme = read('clockin-theme');
  if(!['light','dark'].includes(theme))theme=null;
  const language = read('clockin-language') === 'tr' ? 'tr' : 'en';
  function applyTheme(){
    document.documentElement.dataset.theme=theme || (system.matches?'dark':'light');
    document.documentElement.style.colorScheme=document.documentElement.dataset.theme;
    document.dispatchEvent(new Event('clockin-theme'));
  }
  window.ClockinPreferences={language,saveLanguage:value=>write('clockin-language',value),toggleTheme(){theme=document.documentElement.dataset.theme==='dark'?'light':'dark';write('clockin-theme',theme);applyTheme();}};
  system.addEventListener('change',()=>{if(!theme)applyTheme();});
  applyTheme();
})();
