function rust-new
    # Check if the user provided an argument
    if test (count $argv) -ne 1
        echo "Usage: rust-new <project_name>"
        return 1
    end

    # Store the first argument as project name
    set project_name $argv[1]

    # Check if cargo is available and create a new Rust project
    if not type -q cargo
        echo "cargo not found, using nix-shell -p Rust to create the project."
        nix-shell -p cargo --command "cargo new $project_name"
    else
        cargo new $project_name
    end

    # Check if the cargo command was successful
    if test $status -ne 0
        echo "Failed to create project: $project_name"
        return 1
    end

    # Copy the flake.nix file into the new project directory
    cp $HOME/.dotfiles/misc/envs/rust/flake.nix $project_name/
    
    # Print a success message
    echo "Successfully created project: $project_name and copied default Rust flake.nix"
end
