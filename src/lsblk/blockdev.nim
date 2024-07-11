import std/[paths, os, options, macros, strutils, symlinks]
import results
import blockdev/stat

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

## Get the disk name if `self` is a partition, else return self.name
proc disk_name*(self: BlockDevice): string # forward declare

## Fetch the size of the device.
##
## This relies on `sysfs(5)`, i.e. the file system mounted at `/sys`.
##
## The returned value * 512 = size in bytes.
proc size*(self: BlockDevice): Option[int] {.raises: [].} =
  try:
    let p = "/sys/block" & (
      if self.is_part: "/" & self.disk_name
      else: "") & "/" & self.name & "/size"
    some readFile(p)[0..^2].parseInt # need to remove \n
  except:
    return none(int)

## Get the major, minor ID of the block-device.
proc maj_min*(self: BlockDevice): tuple[maj: uint, min: uint] =
  var rawInfo: Stat
  if stat.lstat(self.fullname.cstring, rawInfo) < 0'i32:
    raiseOSError(osLastError(), self.fullname)
  let rdev: uint = rawInfo.st_rdev
  let maj = (rdev shr 32) and 0xfffff000.uint or (rdev shr 8) and 0xfff
  let min = (rdev shr 12) and 0xffffff00.uint or rdev and 0xff
  (maj: maj, min: min)

## Get the major, minor ID of the block-device.
proc major_minor*(self: BlockDevice): tuple[maj: uint, min: uint] = maj_min(self)


## Get the sysfs path for this block device.
##
## This relies on `sysfs(5)`, i.e. the file system mounted at `/sys`.
proc sysfs*(self: BlockDevice): Path =
  let (maj, min) = self.maj_min
  Path "/sys/dev/block/" & $maj & ":" & $min


## Get the disk name if `self` is a partition, else return self.name
proc disk_name*(self: BlockDevice): string =
  if not self.is_part:
    self.name
  else:
    self.sysfs.expandSymlink.parentDir.extractFilename.string
