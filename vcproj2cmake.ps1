# history
# 2010.12.1		remove CMakeList_t.txt by here string
#


# Warning: supports VS2005 only. not tested any other version
#
# usage example
# powershell .\vcproj2cmake.ps1 c:\xxx.vcproj -conf "Debug"

param(
[string] $file=$(throw 'vcproj file is required'),
[string] $conf='SHP Debug|Win32'
)

$Template = @'
# -*- cmake -*-
# written by Darren Ha(darren.ha@samsung.com)

# replace <target> with binary name. e.g. mbase or FBase
SET (this_target <target>)
#PROJECT(${this_target})

## section: include directory

INCLUDE_DIRECTORIES(
  <include>
  )

## section: source files
# Add your source files here (one file per line), please SORT in alphabetical order for future maintenance
SET (${this_target}_SOURCE_FILES
	<src>
	)

## section: header files
# Add your header files here(one file per line), please SORT in alphabetical order for future maintenance!
SET(${this_target}_HEADER_FILES
	<header>
	)

SET_SOURCE_FILES_PROPERTIES(${this_target}_HEADER_FILES
                            PROPERTIES HEADER_FILE_ONLY TRUE)
LIST(APPEND ${this_target}_SOURCE_FILES ${${this_target}_HEADER_FILES})

## section: add definitions
# 	add prefix -D. example> -DSHP
#  - DO NOT add  the following definitions(already defined in ${OSP_DEFINITIONS}:
# 	-DSHP, -DWIN32, -D_WINDOWS, -D_DEBUG, -D_USRDLL, -D_CRT_SECURE_NO_DEPRECATE
ADD_DEFINITIONS(
	<def> 
	)

## section: add target
ADD_LIBRARY (${this_target} SHARED ${${this_target}_SOURCE_FILES} )

## section: add dependency
# dependency determines overall build order.
ADD_DEPENDENCIES(${this_target} <lib>)

## section: set link libraries
TARGET_LINK_LIBRARIES( ${this_target}
		<lib>)
'@

function ConvToCMake($vcprojFile, $prjConf){
	$files = @()
	[xml]$proj  = gc $vcprojFile
	$proj.selectNodes("/VisualStudioProject/Files//File") | 
		% {
			$_.RelativePath
			if ($_.FileConfiguration -and ($_.FileConfiguration.GetType().name -eq 'Object[]')){
				#$_.RelativePath 			
				$exclude = $false
				foreach ($f in $_.FileConfiguration){
					#$f
					if ($f.Name -eq $prjConf -and $f.ExcludedFromBuild -eq 'true'){
						$exclude = $true
						Write-Host skipping $_.RelativePath
						break
					}
				}				
				if (!$exclude){
					#Write-Host adding $_.RelativePath 
					$file = $_.RelativePath -replace '\\','/'; $files+=$file			
				}
				
				#$_.SelectSingleNode("FileConfiguration[@Name=""$slnConf""][@excludedFromBuild=yes]")
				#$_.FileConfiguration
				#$destNode
				#Read-Host
			}elseif ($_.FileConfiguration ){
				if ($_.FileConfiguration.Name -eq $prjConf -and $_.FileConfiguration.ExcludedFromBuild -eq 'true'){				
					Write-Host skipping $_.RelativePath 
				}else{				
					$file = $_.RelativePath -replace '\\','/'; $files+=$file
				}
			}else{
				#Write-Host adding $_.RelativePath 
				$file = $_.RelativePath -replace '\\','/'; $files+=$file
			}			
		}
	
	$src=@()
	$header=@()
	foreach ($f in $files)
	{
		if ($f -match '\.h'){
			$header += $f
		}else{
			$src += $f
		}
	}
	$header = $header | sort
	$src = $src | sort
	
	# header & src files
	$text = $Template -replace '<src>',[string]::Join("`n`t", $src)
	$text = $text -replace '<header>',[string]::Join("`n`t", $header)
	$text = $text -replace '<target>',$proj.VisualStudioProject.name
	# link lib
	$target = $proj.SelectSingleNode("/VisualStudioProject/Configurations/Configuration[@Name=""$prjConf""]/Tool[10]")
	$raw = $target.AdditionalDependencies
	$raw = $raw -replace '\.lib',''
	$text = $text -replace '<lib>',$raw
	# definition	
	$target = $proj.SelectSingleNode("/VisualStudioProject/Configurations/Configuration[@Name=""$prjConf""]/Tool[6]")
	$target.PreprocessorDefinitions
	$text = $text -replace '<def>',$target.PreprocessorDefinitions
	#include 	
	$raw = $target.AdditionalIncludeDirectories
	$raw = $raw -replace '\\','/'
	$raw = $raw -replace ';',"`n`t"
	$text = $text -replace '<include>',$raw
	
	#save
	$path = Split-Path $vcprojFile
	$text | Out-File (Join-Path $path CMakeLists.txt) -Encoding ASCII
}

ConvToCMake $file "$conf|Win32"

