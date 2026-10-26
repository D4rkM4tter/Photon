import Std.Convert.*;
import Std.Math.*;

@EntryPoint()
operation Main() : Unit {
    // These are ordinary numbers, not qubits. The array positions name accounts:
    //                           A  B  C  D
    let accountEvidenceScores = [3, 2, 1, 0];
    // Higher numbers represent stronger evidence for investigation.
    // Connections between accounts are defined in ConnectionBonus below.
    Message("Select two accounts for review. Selected does not mean guilty.");
    RunBankingExample("Account review example", accountEvidenceScores);
}

// CLASSICAL CONTROL: try circuit settings and keep the best average score.
// Think of this operation as the experiment coordinator, not the quantum circuit.
// Input: four already assigned evidence scores in account order A, B, C, D.
// Goal: propose accounts worth reviewing together under our toy scoring rule.
// It performs classical work and calls the quantum circuit through helpers.
operation RunBankingExample(name : String, accountEvidenceScores : Int[]) : Unit {
    Message("");
    Message($"{name}: account evidence [A, B, C, D] = {accountEvidenceScores}");
    // STEP 1: Establish an answer we can compare the experiment against.
    // With only four accounts, a classical helper can check all 16 selections.
    // It returns the best selection AND its score (9 for A-B with these inputs).
    // We do not give this answer to QAOA; it is only an evaluation reference.
    let (referenceSelection, referenceScore) = FindBestClassicalSelection(accountEvidenceScores);
    Message($"Classical reference: {DescribeSelection(referenceSelection)}, score {referenceScore}");

    // Gamma controls how strongly scores affect phases; beta controls mixing.
    // Both are rotation settings in radians. Trying a small grid is an easy
    // first optimizer: the circuit does not find these settings by itself.
    // STEP 2: Tune the quantum circuit using repeated trials.
    // Gamma and beta are circuit controls, not account evidence or AML thresholds.
    // Gamma controls score-dependent phases; beta mixes alternative selections.
    // Larger angles do not necessarily produce better proposals.
    mutable bestGamma = 0.0;
    mutable bestBeta = 0.0;
    // -100 is simply a starting value below every possible score in this example.
    mutable bestAverage = -100.0;
    // Try 16 x 8 = 128 settings. The step numbers become angles in radians.
    // Account evidence and connections stay unchanged throughout this search.
    for gammaStep in 0..15 {
        for betaStep in 0..7 {
            let gamma = 2.0 * PI() * IntAsDouble(gammaStep) / 16.0;
            let beta = PI() * IntAsDouble(betaStep) / 8.0;
            // Run 64 fresh circuits at these settings and average proposal scores.
            // Score = account evidence + connection bonuses - budget penalty.
            // Measurements are random, so this average is an estimate.
            let average = EstimateAverageScore(accountEvidenceScores, gamma, beta);
            // Remember the settings producing the highest estimated mean score.
            // We are choosing a proposal distribution, not one fixed account pair.
            if average > bestAverage {
                set bestAverage = average;
                set bestGamma = gamma;
                set bestBeta = beta;
            }
        }
    }
    Message($"Chosen settings: gamma={bestGamma}, beta={bestBeta}");

    // Use fresh measurements to evaluate the chosen settings. One measurement
    // gives one proposed selection, so repeat to see how often it works well.
    // STEP 3: Hold those settings fixed and test them on 512 NEW circuit runs.
    // Fresh runs help check whether the settings work beyond their tuning samples.
    // false means not selected; this initial array is only a result placeholder.
    mutable bestSelection = [false, false, false, false];
    mutable bestScore = -100;
    // Track both typical quality (mean score) and exact-optimum frequency.
    // These measure different things: a higher mean need not mean more optimal hits.
    mutable totalScore = 0;
    mutable optimumHits = 0;
    for shot in 1..512 {
        // One complete circuit run proposes one set of accounts, such as A and B.
        // The soft budget allows proposals with other than two accounts as well.
        let selection = ProposeAccountSelection(accountEvidenceScores, bestGamma, bestBeta);
        // Evaluate the proposal with ordinary Q# arithmetic after measurement.
        // A high score means useful for review in this model, not proven laundering.
        let score = ReviewScore(selection, accountEvidenceScores);
        // Print just the first five proposals to show the variation between runs.
        if shot <= 5 { Message($"Example proposal: {DescribeSelection(selection)}, score {score}"); }
        set totalScore += score;
        // Use the classical reference to count how often an optimal score appears.
        if score == referenceScore { set optimumHits += 1; }
        // Keep the best individual proposal seen, separately from the mean score.
        if score > bestScore {
            set bestScore = score;
            set bestSelection = selection;
        }
    }
    // STEP 4: Report the best observed choice, average quality, and optimal hits.
    // QAOA is probabilistic: another run may choose different settings or proposals.
    Message($"Best proposal: {DescribeSelection(bestSelection)}, score {bestScore}");
    Message($"Evaluation mean={IntAsDouble(totalScore) / 512.0}; optimal proposals={optimumHits}/512");
    // Comparison: independently choosing yes/no for each account gives 16 equally
    // likely selections. For these inputs their mean score is -1, and only A-B
    // is optimal. This baseline must be recalculated if the banking model changes.
    Message("Uniform random baseline for this example: mean=-1, optimum chance=1/16.");
}

// QUANTUM PART: one run of a one-layer (p=1) QAOA circuit.
operation ProposeAccountSelection(accountEvidenceScores : Int[], gamma : Double, beta : Double) : Bool[] {
    // HERE the four account qubits are allocated. Each starts in |0>, meaning
    // 'not selected'. Each qubit represents a decision, not the account's data.
    use accountA = Qubit();
    use accountB = Qubit();
    use accountC = Qubit();
    use accountD = Qubit();
    let accounts = [accountA, accountB, accountC, accountD];

    // 1. Prepare equal amplitudes for all 16 possible selections.
    // The risk numbers stay classical; we do not load them into these qubits.
    for account in accounts { H(account); }

    // 2. Encode the review score into relative phases of the possible selections.
    // A phase alone does not change the probabilities of measuring those choices.
    ApplyReviewScorePhases(accounts, accountEvidenceScores, gamma);

    // 3. The mixer makes alternatives interfere, changing their probabilities.
    // Good gamma/beta settings can favor higher-scoring choices, without a guarantee.
    for account in accounts { Rx(2.0 * beta, account); }

    // 4. Measure one concrete proposal. One means selected for investigation.
    let selection = [M(accountA) == One, M(accountB) == One,
                     M(accountC) == One, M(accountD) == One];
    // Return every qubit to |0> before releasing it. The next shot starts afresh.
    for account in accounts { Reset(account); }
    return selection;
}

operation ApplyReviewScorePhases(accounts : Qubit[], accountEvidenceScores : Int[], gamma : Double) : Unit {
    // R1(angle) changes the phase of |1> only. Here |1> means 'selected'.
    // The minus sign implements the QAOA cost unitary exp(-i gamma * score).
    for i in 0..3 {
        R1(-gamma * IntAsDouble(accountEvidenceScores[i]), accounts[i]);
    }
    // Controlled R1 changes the phase only when BOTH account decisions are 1.
    // This directly represents the bonus for investigating a connected pair.
    for i in 0..3 {
        for j in i + 1..3 {
            Controlled R1([accounts[i]], (-gamma * IntAsDouble(ConnectionBonus(i, j)), accounts[j]));
        }
    }
    // Encode the same two-account budget penalty used by ReviewScore.
    // For binary decisions x_i and n=sum x_i:
    // -P(n-2)^2 = -4P + 3P sum x_i - 2P sum_(i<j) x_i*x_j.
    // The constant -4P is a common global phase and can be omitted.
    let penalty = IntAsDouble(ReviewBudgetPenalty());
    for i in 0..3 {
        R1(-gamma * 3.0 * penalty, accounts[i]);
        for j in i + 1..3 {
            Controlled R1([accounts[i]], (gamma * 2.0 * penalty, accounts[j]));
        }
    }
}

// BANKING MODEL: entirely synthetic and intentionally small.
// Account indices: A=0, B=1, C=2, D=3. Each link is undirected; i < j.
function ConnectionBonus(i : Int, j : Int) : Int {
    if i == 0 and j == 1 { return 4; } // A-B: strongest shared evidence.
    if i == 1 and j == 2 { return 1; } // B-C: weaker shared evidence.
    if i == 2 and j == 3 { return 3; } // C-D: another connected pair.
    return 0;                         // No bonus for other pairs.
}

function ReviewBudgetPenalty() : Int { return 6; }

function ReviewScore(selected : Bool[], accountEvidenceScores : Int[]) : Int {
    mutable selectedCount = 0;
    mutable score = 0;
    for i in 0..3 {
        if selected[i] {
            set selectedCount += 1;
            set score += accountEvidenceScores[i];
            // Count each link once, and only when both ends are selected.
            for j in i + 1..3 {
                if selected[j] { set score += ConnectionBonus(i, j); }
            }
        }
    }
    // Prefer two reviews: subtract 6 for one or three, 24 for zero or four.
    // This is a soft penalty, so the circuit can still propose other counts.
    let distanceFromBudget = selectedCount - 2;
    return score - ReviewBudgetPenalty() * distanceFromBudget * distanceFromBudget;
}

// SUPPORTING CLASSICAL HELPERS. No quantum gates are needed for these checks.
function DescribeSelection(selected : Bool[]) : String {
    return $"A={selected[0]}, B={selected[1]}, C={selected[2]}, D={selected[3]}";
}

operation EstimateAverageScore(accountEvidenceScores : Int[], gamma : Double, beta : Double) : Double {
    mutable total = 0;
    // A 'shot' means preparing, running, and measuring the circuit once.
    for shot in 1..64 {
        let proposal = ProposeAccountSelection(accountEvidenceScores, gamma, beta);
        set total += ReviewScore(proposal, accountEvidenceScores);
    }
    return IntAsDouble(total) / 64.0;
}

function FindBestClassicalSelection(accountEvidenceScores : Int[]) : (Bool[], Int) {
    mutable bestSelection = [false, false, false, false];
    mutable bestScore = -100;
    // Try both decisions for each named account: 2*2*2*2 = 16 combinations.
    // This reference lets us judge QAOA; it is not supplied to the circuit.
    for selectA in [false, true] {
        for selectB in [false, true] {
            for selectC in [false, true] {
                for selectD in [false, true] {
                    let selection = [selectA, selectB, selectC, selectD];
                    let score = ReviewScore(selection, accountEvidenceScores);
                    if score > bestScore {
                        set bestScore = score;
                        set bestSelection = selection;
                    }
                }
            }
        }
    }
    return (bestSelection, bestScore);
}