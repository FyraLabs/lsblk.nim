import std/[paths, os, options, macros, strutils]
import results

type BlockDevice* = object of RootObj
  name*: string
  fullname*: string
  diskseq*: Option[string]
  path*: Option[string]
  uuid*: Option[string]
  partuuid*: Option[string]
  label*: Option[string]
  partlabel*: Option[string]
  id*: Option[string]


iterator ls_symlinks(dir: string): tuple[dest: string, src: string] =
  if dir.dirExists:
    for (kind, path) in dir.walkDir:
      if kind == pcLinkToFile:
        var dest = path.expandSymlink
        dest.removePrefix "../../"
        yield (dest: dest, src: path.relativePath(dir))

macro insertbd(index: var seq[string], bds: var seq[BlockDevice], kind: untyped) =
  let kindstr = kind.toStrLit
  quote do:
    for (name, src) in ls_symlinks("/dev/disk/by-"&`kindstr`):
      let i = `index`.find(name)
      if i == -1:
        `index`.add name
        `bds`.add BlockDevice(name: name, fullname: "/dev/"&name, `kind`: some(src))
      else:
        `bds`[i].`kind` = some(src)

proc listBlockDevices*(): seq[BlockDevice] =
  var index: seq[string]
  for (name, src) in ls_symlinks("/dev/disk/by-diskseq"):
    index.add name
    result.add BlockDevice(name: name, fullname: "/dev/"&name, diskseq: some(src))
  insertbd(index, result, path)
