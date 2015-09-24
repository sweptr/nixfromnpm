{ stdenv, fetchurl, openssl, python, zlib, libuv, v8, utillinux, http-parser
, pkgconfig, runCommand, which, libtool
}:

# nodejs 0.12 can't be built on armv5tel. Armv6 with FPU, minimum I think.
# Related post: http://zo0ok.com/techfindings/archives/1820
assert stdenv.system != "armv5tel-linux";

let
  version = "4.1.1";

  deps = {
    inherit openssl zlib libuv;

    # disabled system v8 because v8 3.14 no longer receives security fixes
    # we fall back to nodejs' internal v8 copy which receives backports for now
    # inherit v8
  } // (stdenv.lib.optionalAttrs (!stdenv.isDarwin) {
    inherit http-parser;
  });

  sharedConfigureFlags = name: [
    "--shared-${name}"
    "--shared-${name}-includes=${builtins.getAttr name deps}/include"
    "--shared-${name}-libpath=${builtins.getAttr name deps}/lib"
  ];

  inherit (stdenv.lib)
    concatMap optional optionals maintainers licenses platforms;
in

stdenv.mkDerivation {
  name = "nodejs-${version}";


  src = fetchurl {
    url = "http://nodejs.org/dist/v${version}/node-v${version}.tar.gz";
    sha256 = "0n2sw622nyl1y0v48i1sjgblzqi24c02csmgy8y73pjjzwshjqba";
  };

  configureFlags = concatMap sharedConfigureFlags (builtins.attrNames deps) ++
                     [ "--without-dtrace" ];

  prePatch = ''
    patchShebangs .
  '';

  patches = stdenv.lib.optional stdenv.isDarwin ./no-xcode.patch;

  buildInputs = [ python which ]
    ++ optional stdenv.isLinux utillinux
    ++ optionals stdenv.isDarwin [ pkgconfig openssl libtool ];

  setupHook = ''
    addNodePath () {
      addToSearchPath NODE_PATH $1/lib/node_modules
    }

    envHooks+=(addNodePath)
  '';

  enableParallelBuilding = true;

  passthru.interpreterName = "nodejs";

  meta = {
    description = "Event-driven I/O framework for the V8 JavaScript engine";
    homepage = http://nodejs.org;
    license = licenses.mit;
    maintainers = [ maintainers.goibhniu maintainers.havvy ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}