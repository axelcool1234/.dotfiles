{
  lib,
  stdenvNoCC,
  fetchurl,
  makeDesktopItem,
  copyDesktopItems,
  makeWrapper,
  steam-run-free,
}:

let
  version = "0.1.60a";
  sources = {
    x86_64-linux = {
      url = "https://github.com/glide-browser/glide/releases/download/${version}/glide.linux-x86_64.tar.xz";
      hash = "sha256-3/qvFTURly9yTUzvGaaJfIGGr3rE4YKNoPwYe8rg1sI=";
    };
    aarch64-linux = {
      url = "https://github.com/glide-browser/glide/releases/download/${version}/glide.linux-aarch64.tar.xz";
      hash = "sha256-OgjKChqeuObVgEirWKFgT6NqaXlzy6J4pPkt6hV+daY=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "glide-browser is only packaged for Linux on x86_64 and aarch64");

  desktopItem = makeDesktopItem {
    name = "glide";
    desktopName = "Glide";
    exec = "glide %U";
    icon = "glide";
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeTypes = [
      "application/xhtml+xml"
      "text/html"
      "text/xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    startupWMClass = "glide";
    terminal = false;
  };
in
stdenvNoCC.mkDerivation {
  pname = "glide-browser";
  inherit version;

  src = fetchurl source;
  sourceRoot = "glide";

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
  ];

  desktopItems = [ desktopItem ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/glide-browser"
    cp -R . "$out/lib/glide-browser"

    makeWrapper ${steam-run-free}/bin/steam-run "$out/bin/glide" \
      --add-flags "$out/lib/glide-browser/glide"

    for size in 16 32 48 64 128; do
      icon_dir="$out/share/icons/hicolor/''${size}x''${size}/apps"
      mkdir -p "$icon_dir"
      cp "browser/chrome/icons/default/default''${size}.png" "$icon_dir/glide.png"
    done

    runHook postInstall
  '';

  meta = {
    description = "Extensible and keyboard-focused web browser launched through steam-run";
    homepage = "https://glide-browser.app/";
    changelog = "https://github.com/glide-browser/glide/releases/tag/${version}";
    license = lib.licenses.mpl20;
    mainProgram = "glide";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
