when defined(amd64):
  type Stat* {.importc: "struct stat", header: "<sys/stat.h>", final, pure.} = object
    st_rdev*: uint
else:
  type Stat* {.importc: "struct stat", header: "<sys/stat.h>", final, pure.} = object
    st_rdev*: uint
  proc modeIsDir(m: Mode): bool {.importc: "S_ISDIR", header: "<sys/stat.h>".}
    ## Test for a directory.
proc lstat*(a1: cstring, a2: var Stat): cint {.importc, header: "<sys/stat.h>", sideEffect.}
