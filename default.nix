(import <nixpkgs> {
  config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };
}).callPackage (

{ mkShell
, gradle
, android-studio
, androidenv
, buildFHSEnv
, strace
}:

let
  androidPkgs = (androidenv.composeAndroidPackages {
    includeNDK = true;
    platformVersions = [
      "34"
    ];
    buildToolsVersions = [
      "34.0.0"
    ];
  });
  sdk = androidPkgs.androidsdk;
  fhsEnv = buildFHSEnv {
    name = "my-camera-fhs-env";
    multiPkgs = pkgs: [
      strace
    ];
  };
in
mkShell {
  nativeBuildInputs = [
    #(android-studio.withSdk sdk)
    sdk
    gradle
    fhsEnv
  ];

  ANDROID_HOME = "${sdk}/libexec/android-sdk";

  shellHook = ''
    _fhs() {
    ${fhsEnv}/bin/${fhsEnv.name} -c 'exec $@' -- "$@"
    }
    gradle() {
      _fhs ${gradle}/bin/gradle --no-daemon "$@"
    }
    build() {
      (
      PS4=" $ "
      set -x
       gradle assemble
      )
    }
    cleanup() {
      # See files git ignores:
      #  $ git status --ignored --untracked-files=all
      # Also consider `trash ~/.gradle/`
      rm -vrf ${toString ./.}/{local.properties,app/build,.gradle}
    }

    run() {
      APK=app/build/outputs/apk/release/app-release.apk
      if ! test -e "$APK"; then
        build
      fi
      APPLICATION_ID=com.samueldr.mycamera
      PACKAGE_NAME=net.sourceforge.opencamera
      adb install "$APK"
      adb shell am start -n "$APPLICATION_ID/$PACKAGE_NAME.MainActivity"
    }
  '';
}
) {}
