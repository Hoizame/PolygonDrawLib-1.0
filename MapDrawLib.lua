local AddonName = ...
local LibPath = GetAddOnMetadata(AddonName, "X-MapDrawLib-Path")
assert(LibPath, "X-MapDrawLib-Path for \"MapDrawLib\" not found! ".." Set ## X-MapDrawLib-Path: in the "..AddonName..".toc")

local MAJOR, MINOR = "MapDrawLib", 1
assert(LibStub, MAJOR .. " requires LibStub")

local MDL, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not MDL then return end
