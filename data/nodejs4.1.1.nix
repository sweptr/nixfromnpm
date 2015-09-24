{ stdenv, fetchurl, openssl, python, zlib, libuv, v8, utillinux, http-parser
, pkgconfig, runCommand, which, libtool
}:

assert stdenv.system != "armv5tel-linux";

let
  version = "4.1.1";
  inherit (stdenv.lib)
    attrNames attrValues concatMap optional optionals maintainers
    licenses platforms;
in

stdenv.mkDerivation {
  name = "nodejs-${version}";

  src = fetchurl {
    url = "http://nodejs.org/dist/v${version}/node-v${version}.tar.gz";
    sha256 = "0n2sw622nyl1y0v48i1sjgblzqi24c02csmgy8y73pjjzwshjqba";
  };

  # Configure doesn't recognize the --disable-static flag
  dontDisableStatic = true;

  prePatch = ''
    patchShebangs .
  '';

  patches = stdenv.lib.optional stdenv.isDarwin ./no-xcode.patch;

  buildInputs = [ python which openssl zlib libuv http-parser ]
    ++ optional stdenv.isLinux utillinux
    ++ optionals stdenv.isDarwin [ pkgconfig openssl libtool ];

  setupHook = ./setup-hook.sh;
  enableParallelBuilding = true;

  passthru = {
   inherit version;
   interpreterName = "nodejs";
  };

  meta = {
    description = "Event-driven I/O framework for the V8 JavaScript engine";
    homepage = http://nodejs.org;
    license = licenses.mit;
    maintainers = [ maintainers.goibhniu maintainers.havvy ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
