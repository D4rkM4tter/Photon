
operation RandomBit() : Result {

    //This operation allocates a qubit initialized to 0
    use qubit = Qubit();

    // Apply a Hadamard gate to the qubit to create a superposition state of 0 and 1
    H(qubit);

    // Measure the qubit, collapsing it to either 0 or 1 and storing the result
    let result = M(qubit);

    // Reset the qubit to its initial state (0) before releasing it back to the quantum simulator
    Reset(qubit);
    return result;
}


@EntryPoint()
operation Main() : Unit {

    for i in 1..10 {
        
        // Call the RandomBit operation to generate a random bit
        let bit = RandomBit();
        
        Message($"Random bit {i}: {bit}");
    }
}