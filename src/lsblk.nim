import std/[streams, strformat, strscans, paths, os, options, macros, strutils]
import results
export results

type
  Mount* = object of RootObj
    device*: string
    mountpoint*: string
    fstype*: string
    mountopts*: string
  BlockDevice* = object of RootObj
    name*: string
    fullname*: string
    diskseq*: Option[string]
    path*: Option[string]
    uuid*: Option[string]
    partuuid*: Option[string]
    label*: Option[string]
    partlabel*: Option[string]
    id*: Option[string]

proc notSpace(input: string, match: var string, start: int): int =
  result = 0
  while input[start+result] != ' ': inc result
  match = input[start..start+result-1]


proc getMounts*(): Result[seq[Mount], string] =
  var res: seq[Mount] = @[]
  var fdmounts = newFileStream("/proc/mounts")
  if fdmounts == nil:
    # cannot open file
    return ok seq[Mount](@[])
  defer: fdmounts.close()
  var linenum = 0
  var line, dev, mp, fstype, mountopts: string
  while fdmounts.readLine line:
    inc linenum
    if scanf(line, "${notSpace} ${notSpace} ${notSpace} ${notSpace} 0 0$.", dev, mp, fstype, mountopts):
      res.add Mount(device: dev, mountpoint: mp, fstype: fstype, mountopts: mountopts)
    else:
      return err fmt"Fail to parse /proc/mounts:{linenum} : {line}"
  ok res

proc listMounts*(): Result[seq[Mount], string] =
  getMounts()

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
