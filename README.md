# Photon

Independent Q# experiments using the Microsoft Quantum Development Kit (QDK).

## Setup

Install Visual Studio Code and the Microsoft Quantum Development Kit (QDK) extension
(extension ID: quantum.qsharp-lang-vscode). No .NET SDK or Python installation is
required to run these experiments in the extension's local simulator.

## Run an experiment

1. Open this Photon folder in VS Code.
2. Open RandomBit/src/Main.qs or BellPair/src/Main.qs.
3. Click Run above Main, or press Ctrl+F5.

RandomBit returns Zero or One with equal probability. BellPair returns
(Zero, Zero) or (One, One), each with equal probability. Small samples will vary.

## Add an experiment

Create YourExperiment/qsharp.json containing {}, then place Q# source
files under YourExperiment/src/. Give each experiment its own Main
operation. The separate manifests keep the projects independent.

For larger experiments, add supporting .qs files under that experiment's src
folder. Shared libraries can be introduced later as project dependencies.

Current Q# projects use qsharp.json; this repository does not require a .sln.

Documentation: https://learn.microsoft.com/en-us/azure/quantum/how-to-work-with-qsharp-projects
