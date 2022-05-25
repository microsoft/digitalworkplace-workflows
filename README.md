# DigitalWorkplace Workflows

This repo provides a set of Github workflow templates to be used by Microsoft.DigitalWorkplace team for building, packing, signing and publishing NuGet package projects.

The templates take inputs and secrets as needed to run their defined behavior and stable_publish.yml workflow is the only one that assumes a Release environment, mainly for approval purposes.

## Workflow overviews

### build.yml

Runs the basic build steps and test steps and generates NuGet packages for the project specified in the input.

### pack.yml

Packs the given project and verifies the project has the correct metadata for Microsoft using a downloaded script, then uploads the nupkg to an 'unsigned' artifact - intended to be used later by the *sign* workflow.

### sign.yml

Communicates with ESRP (a Microsoft internal tool for signing NuGet packages) using their client and signs the packag in the artifact folder - it assumes an `unsigned` artifact folder exists with the corresponding .nupkg file. After signing the package it uploads it to the `signed` artifact folder.

### beta_publish.yml and stable_publish.yml [deprecated]

Pushes the signed nupkg files to the public NuGet.org feed.

### publish.yml

Pushes the signed nupkg file to the public NuGet.org feed.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
