{ stdenv
, runCommand
, fetchFromGitHub
, pulseaudio
, pkgconfig
, ffmpeg_4
, patchelf
, fdk_aac
, libtool
, cmake
, bluez
, dbus
, sbc
, lib
}:

let
  pulseSources = runCommand "pulseaudio-sources" {} ''
    mkdir $out
    tar -xf ${pulseaudio.src}
    mv pulseaudio*/* $out/
  '';

in stdenv.mkDerivation rec {
  name = "pulseaudio-modules-bt-${version}";
  version = "unstable-2019-04-12";

  src = fetchFromGitHub {
    owner = "EHfive";
    repo = "pulseaudio-modules-bt";
    rev = "9ff89b430c67e98eb3a74e0f06a8957449e21927";
    sha256 = "1sffm08mjizri2mx2rjpfwqgsbpy2b8v92nkvwl1s0j51dji6s6r";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    pkgconfig
    patchelf
    cmake
  ];

  buildInputs = [
    pulseaudio
    ffmpeg_4
    fdk_aac
    libtool
    bluez
    dbus
    sbc
  ];

  postPatch = ''
    # Upstream bundles pulseaudio as a submodule
    rm -r pa
    ln -s ${pulseSources} pa

    # Pulseaudio version is detected with a -rebootstrapped suffix which build system assumptions
    substituteInPlace config.h.in --replace PulseAudio_VERSION ${pulseaudio.version}
    substituteInPlace CMakeLists.txt --replace '${"\${PulseAudio_VERSION}"}' ${pulseaudio.version}
    sed -i 's:LIBRARY DESTINATION ''${PulseAudio_modlibexecdir}:LIBRARY DESTINATION ''${CMAKE_INSTALL_PREFIX}/lib/pulse-''${PulseAudio_VERSION}/modules/:' CMakeLists.txt
  '';

  postFixup = ''
    for so in $out/lib/pulse-${pulseaudio.version}/modules/*.so; do
      orig_rpath=$(patchelf --print-rpath "$so")
      patchelf \
        --set-rpath "${lib.getLib ffmpeg_4}/lib:$out/lib/pulse-${pulseaudio.version}/modules:$orig_rpath" \
        "$so"
    done
  '';

  meta = with stdenv.lib; {
    homepage = https://github.com/EHfive/pulseaudio-modules-bt;
    description = "LDAC, aptX, aptX HD, AAC codecs (A2DP Audio) support for Linux PulseAudio";
    platforms = platforms.linux;
    license = licenses.mit;
    maintainers = with maintainers; [ adisbladis ];
  };
}
