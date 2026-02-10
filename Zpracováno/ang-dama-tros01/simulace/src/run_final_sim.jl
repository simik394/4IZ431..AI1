include("testvaluefunc.jl")

# Run the simulation with output redirected to "simulation_outputs"
# The structure will be simulation_outputs/run_<timestamp>/...
run_assignment_simulation(
    search_depth=6,
    num_turns=15, # Increased turns to ensure completion
    save_trees=true,
    output_base_dir="simulation_outputs"
)
