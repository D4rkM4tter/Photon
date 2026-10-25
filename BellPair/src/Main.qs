operation Main() : (Result, Result) {
    use (first, second) = (Qubit(), Qubit());
    H(first);
    CNOT(first, second);
    let results = (M(first), M(second));
    Reset(first);
    Reset(second);
    return results;
}
