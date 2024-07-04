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
  insertbd(index, result, uuid)
  insertbd(index, result, partuuid)
  insertbd(index, result, label)
  insertbd(index, result, partlabel)
  insertbd(index, result, id)

func is_part*(self: BlockDevice): bool = self.partuuid.is_some
func is_disk*(self: BlockDevice): bool = not self.is_part
func is_physical*(self: BlockDevice): bool = self.path.is_some

## If the block-device is a partition, trim out the partition from name and return the name of the
## disk.
##
## This function is **_EXPENSIVE_** because IO is involved. Specifically, this function reads the
## content of the directory `/sys/block` for a list of disks.
proc disk_name*(self: BlockDevice): Option[string] =
  for (_, diskname) in "/sys/block".walkDir(true, true):
    if self.name.starts_with diskname:
      return some diskname
  none(string)

## Fetch the size of the device.
##
## This relies on `sysfs(5)`, i.e. the file system mounted at `/sys`.
##
## The returned value * 512 = size in bytes.
proc size*(self: BlockDevice): Option[int] {.raises: [].} =
  try:
    let p = "/sys/block" & (
      if self.is_part: "/" & self.disk_name.get
      else: "") & "/" & self.name & "/size"
    some readFile(p)[0..^2].parseInt # need to remove \n
  except:
    return none(int)
