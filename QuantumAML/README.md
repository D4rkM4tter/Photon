# QuantumAML: a banking quantum Hello World

The question: which two of four synthetic accounts should an investigator review?
We assign evidence scores to accounts and bonuses to connected pairs, then use
one layer of QAOA to propose selections. All code is Q#; no Python, C#, external
banking systems, cloud credentials, or real customer data are involved.

## Run

Open Photon or QuantumAML in VS Code with the Microsoft Quantum Development Kit
extension (`quantum.qsharp-lang-vscode`). Open `src/Main.qs`, then click **Run**
above `Main` or press Ctrl+F5. Use the local simulator and unrestricted profile.
`qsharp.json` contains `{}`, matching BellPair and RandomBit. No other VS Code
configuration or host program is required.

## Read the code in this order

1. **Main** initializes the ordinary account evidence numbers. Every array uses
   account order A, B, C, D. These numbers are classical input, not qubit states.
2. **RunBankingExample** tries circuit settings, then evaluates the best settings
   with fresh proposals. This is the classical control loop, written in Q#.
3. **ProposeAccountSelection** is the quantum circuit. The four `use accountA =
   Qubit()` etc. lines initialize the four decision qubits in |0>. Each qubit
   answers one question: should this account be selected?
4. **ApplyReviewScorePhases** encodes the score as phases. Read its first two
   loops as 'account evidence' and 'connected-pair evidence'. The final loop
   implements the two-account review-budget preference.
5. **ConnectionBonus** and **ReviewScore** define the synthetic banking model.
   The remaining helpers format output, average shots, and check all selections.

The circuit starts with H on each account qubit, preparing equal amplitudes for
all 16 selections. It applies score-dependent phases, then Rx mixing rotations
that let those phases affect measurement probabilities. Measurement produces
one proposal, printed as `A=true, B=false, ...`. Reset releases clean qubits;
each shot starts with a fresh preparation. A shot is one circuit execution.

There is no integer mask or bit shifting. The classical reference explicitly
tries true/false for each named account. A `function` performs classical work;
an `operation` can execute gates and measurements (and classical work too).

## The toy model

| Account | Evidence score |
| --- | ---: |
| A | 3 |
| B | 2 |
| C | 1 |
| D | 0 |

The network has undirected connections A-B (bonus 4), B-C (bonus 1), and C-D
(bonus 3). Other pairs have no connection bonus. These values stand in for
pre-scored evidence; the demo does not process transactions or classify fraud.

Score = selected account evidence + bonuses between selected accounts
        - 6 * (number selected - 2)^2.

The penalty prefers two accounts but does not forbid other counts. Higher is
better. Selecting an account means review, not guilt. The classical best choice
is A-B with score 9. The circuit never receives this answer; it is computed
separately for comparison.

## What to expect

The optimizer tries 16 gamma values and 8 beta values, using 64 shots per pair.
Gamma sets phase strength; beta sets mixer strength, both in radians. The chosen
settings are evaluated with 512 fresh shots. The demo uses 8,704 circuit runs,
with only four qubits live at a time. Output shows five example proposals, the
best sampled proposal, the average evaluation score, and optimal-proposal count.

Results vary. QAOA may sample the wrong number of accounts or miss the optimum.
Maximizing average score does not necessarily increase optimal-hit frequency.
Uniform random selections have mean score -1 and optimum chance 1/16 for this
input. A shallow circuit and a coarse parameter grid offer no guarantee of
beating that baseline. Enumeration is easier for four accounts; this illustrates
quantum optimization mechanics, not quantum advantage or operational AML accuracy.

## Optional gate mathematics

R1(theta) leaves |0> alone and multiplies |1> by exp(i theta). Therefore
R1(-gamma * evidence) encodes an account reward only when that account is selected.
Controlled R1 does the same for a pair, only when both accounts are selected.
Together the phase gates implement exp(-i gamma * score), up to a global phase.

The budget penalty needs an expansion. With binary selections x_i, n=sum x_i,
and P=6:

    -P(n-2)^2 = -4P + 3P sum x_i - 2P sum_(i<j) x_i x_j.

Use single-account R1(-3 gamma P) and pair Controlled R1(2 gamma P); omit the
constant global phase. Rx(2 beta) implements exp(-i beta X), the QAOA mixer.
This is p=1: one phase layer followed by one mixer layer.

## Try changing something

- Edit the account evidence in Main or the links in ConnectionBonus.
- Change ReviewBudgetPenalty to explore the soft review-budget preference.
  Both scoring and gates read this same value.
- Increase shots or grid density to explore sampling noise and parameter search.
- Set gamma to zero: there is no score encoding and outcomes stay uniform.
- Set beta to zero: score phases alone also leave measurement probabilities uniform.

The code deliberately assumes exactly four accounts. The printed baseline is
specific to the supplied input; recompute it if changing the model.

## Validation

Before reducing Main to one scenario, the refactored code compiled and executed using the compiler/simulator bundled
with VS Code QDK 1.33.1. The retained scenario completed and sampled its optimal pair before this simplification.
Separate deterministic checks confirmed the reference selections and scores.
A temporary JavaScript adapter invoked the installed QDK only for validation;
it is not part of the demo. The VS Code Run UI and hardware were not tested.

References: [Q# project structure](https://learn.microsoft.com/en-us/azure/quantum/how-to-work-with-qsharp-projects)
and [QAOA paper](https://arxiv.org/abs/1411.4028).