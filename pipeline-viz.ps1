<#
.SYNOPSIS
    Render a dependency graph of all pipelines under the current directory.

.EXAMPLE
    ./pipeline-viz.ps1 -Mapping @{ SharedTemplates = ".\Repo2\" } -RenderSubgraphs -Export 

.EXAMPLE
    ./pipeline-viz.ps1 -Mapping @{ SharedTemplates = ".\Repo2\" } -RenderSubgraphs | Export-PSGraph -OutputFormat svg -Destination "deps.svg"
#>
[CmdletBinding()]
Param (
    # Map the name of the repository resource used in a pipeline to the directory where it is cloned.
    $Mapping = @{}, 

    # Layout engine used by Graphviz
    $Layout = "dot",

    # Render each repository as its own subgraph (surrounded by a box)
    [switch]$RenderSubgraphs = $False,

    # Render the graph and display it with the default image viewer
    [switch]$Export = $False
)

function Resolve-Path2 {
    <#
    .SYNOPSIS
        Resolve the given path relative to the current directory.
    .DESCRIPTION
        Try to resolve the given path relative to the current directory.
        If it does not exist, return the relative path that was attempted to be resolved.

    .NOTES
        The built-in 'Resolve-Path' only returns existing paths.

    .EXAMPLE
        Resolve-Path2 "./some-dir/../../../some-file.txt"
    #>
    param (
        $FileName
    )

    $FileName = Resolve-Path -Relative $FileName -ErrorAction SilentlyContinue `
        -ErrorVariable _frperror
    if (-not($FileName)) {
        $FileName = $_frperror[0].TargetObject
        $rootDir = Get-Location
        $FileName = ".$($FileName.Substring($rootDir.Path.Length))"
    }

    return $FileName
}

function Normalize-Path {
    <#
    .SYNOPSIS
        Resolve the relative path to the 'target' template from the 'origin'
        template and convert the path so its relative to where the script is started from.

    .EXAMPLE
        > Normalize-Path './Repo1/deploy.yml' 'dotnet.yml@SharedTemplates'
        './Repo2/dotnet.yml'
    #>
    param (
        $origin,
        $target
    )

    # Target is in another repository
    if ($target -like "*@*") {
        $remoteParts = $target -split "@"
        $remote = $remoteParts[-1]
        $remoteTarget = $remoteParts[0]
        if ($remote -in $Mapping.Keys) {
            # reset target to the name of the cloned repo folder and the relative file path
            $target = Join-Path $Mapping[$remote] $remoteTarget

            # reset origin to the relative root where all repo's are cloned
            # Must include a filename, because $origin is expected to be a pipeline file.
            $origin = "./dummy.yml" 
        }
        else {
            return $target.Replace("\", "/")
        }
    }

    $joined = Join-Path (Split-Path -parent $origin) $target
    (Resolve-Path2 $joined).Replace("\", "/")
}

function Add-Edges {
    <#
    .SYNOPSIS
        Find all dependencies of a pipeline and create edges between the pipeline and them.
    #>
    param ($pipeline)
    $templates = $(Select-String "\- template: " $pipeline)
    $templates | % {
        $name = Normalize-Path $pipeline ($($_ -split ": ")[-1].Trim(" ").Trim("'").Trim("`""))
        edge -from "$pipeline" -to "$name"
    }
}

function Add-Subgraphs {
    <#
    .SYNOPSIS
        Define all subgraphs based on the repositories the pipelines are in.
    #>
    param ($pipelines)
    $subgraphs = $pipelines | group { Get-Repo $_ }
    $subgraphs | % {
        subgraph $_.Name.Replace(".", "_") @{Label = $_.Name } {
            node $_.Group -NodeScript { $_ }
        }
    }
}

function Get-Repo {
    <#
    .SYNOPSIS
        Get the name of the repository a "pipeline" is in.
        
    .NOTES
        Assumes the script runs from the parent directory of a repository
    #>
    param ($pipeline)

    ($pipeline -split "/")[1]
}

$graph = graph g @{rankdir = "LR"; layout=$Layout; overlap = $True } {
    $pipelines = Get-ChildItem -Recurse "*.yml" 
    | where { $_.FullName -inotmatch "node_modules" }
    | foreach { (Resolve-Path2 $_.FullName).Replace("\", "/") }

    if ($RenderSubgraphs) {
        Add-Subgraphs $pipelines
    }
    
    $pipelines | % {
        Add-Edges $_
    }
} 

if ($Export) {
    $graph | Export-PSGraph -ShowGraph
}
else {
    $graph
}