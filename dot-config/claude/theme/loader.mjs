// Module loader hook: patches Claude Code's cli.js for OS auto-theme.
// Patch 1: replaces an empty useEffect with one that subscribes to
//          __ccThemeState and sets the theme setting reactively.
// Patch 2: disables the /theme picker since theme follows OS appearance.

export async function load(url, context, nextLoad) {
  const result = await nextLoad(url, context);
  if (!url.endsWith("/cli.js") || !url.includes("claude-code")) return result;

  let source =
    typeof result.source === "string"
      ? result.source
      : Buffer.from(result.source).toString("utf-8");

  // Find the ThemeProvider region via its unique shape
  const providerMarker =
    /\{themeSetting:[$\w]+,[\s\S]{0,500}?currentTheme:[$\w]+\}/;
  const pm = source.match(providerMarker);
  if (!pm || pm.index == null) return result;

  const regionStart = Math.max(0, pm.index - 3000);
  const regionEnd = Math.min(source.length, pm.index + pm[0].length + 500);
  const region = source.slice(regionStart, regionEnd);

  // Find the empty useEffect
  const ueRe =
    /([$\w]+)\.useEffect\(\(\)=>\{\},\[([$\w]+)(?:,([$\w]+))?\]\)/;
  const ue = region.match(ueRe);

  // Find the theme-setting setter (first useState in the provider).
  // Setting it in-memory switches the active theme without persisting to disk.
  // Pattern: let[z,Y]=React.useState(K??RD_),[…
  const tsRe =
    /let\[([$\w]+),([$\w]+)\]=([$\w]+)\.useState\([$\w]+\?\?[$\w]+\),\[/;
  const ts = region.match(tsRe);

  if (!ue || !ts) return result;

  const reactVar = ue[1];
  const dep1 = ue[2];
  const dep2 = ue[3];
  const deps = dep2 ? `${dep1},${dep2}` : dep1;
  const setter = ts[2];

  const replacement =
    `${reactVar}.useEffect(()=>{` +
    `var _s=globalThis.__ccThemeState;` +
    `if(!_s)return;` +
    `${setter}(_s.isDark?"dark":"light");` +
    `var _u=_s.onChange(function(_d){${setter}(_d?"dark":"light")});` +
    `return _u` +
    `},[${deps}])`;

  const absIndex = regionStart + ue.index;
  source =
    source.slice(0, absIndex) +
    replacement +
    source.slice(absIndex + ue[0].length);

  // Patch 2: disable /theme picker - theme follows OS appearance
  source = source.replace(
    'name:"theme",description:"Change the theme"',
    'name:"theme",description:"Theme follows OS appearance (auto)"'
  );
  source = source.replace(
    /(\w+)=async\((\w+),\w+\)=>\{return \w+\.createElement\(\w+,\{onDone:\2\}\)\}/,
    '$1=async($2)=>{return $2("Theme follows OS appearance")}'
  );

  return { ...result, source, shortCircuit: true };
}
