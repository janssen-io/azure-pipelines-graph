# Azure Pipelines Dependency Graph
Renders a dependency graph of all pipelines under the current directory.

![Dependency Graph of the pipelines in this repository. Three subgraphs for Repo1, Repo2 and Repo3 with dependencies from Repo1 to Repo2, Repo3 to Repo2 and Repo2 to a variable template.](demo.png)

## Examples

    > ./pipeline-viz.ps1 -Mapping @{ SharedTemplates = ".\Repo2\" } -RenderSubgraphs -Export 

    > ./pipeline-viz.ps1 | Export-PSGraph -OutputFormat svg -Destination "deps.svg"

## Dependencies
- [Powershell](https://learn.microsoft.com/en-us/powershell/) (tested with v7.4.1)
- [Graphviz](https://graphviz.org/) (tested with v10.0.1)
- [PSGraph](https://github.com/KevinMarquette/PSGraph) (tested with v2.1.38.27)