# STE100 Technical Names: hardware and system entities

The **Hardware and System Entities** category of the [STE100 Technical
Names](index.md) dictionary. These terms name the physical
components and machines that the Ada code interacts with.

## Technical Name: CPU Core
- **Part of Speech:** Noun
- **Definition:** A logical processor on the host machine. The detection
  counts CPU cores to resolve gnatprove parallelism.
- **Approved Form:** CPU Core (singular), CPU Cores (plural)
- **Do Not Use:** Processor (when the core is meant), CPU (when one core is
  meant)
- **Correct Example:** *The tool detects 16 **CPU cores** on the host.*
- **Incorrect Example:** *The tool detects 16 processors on the host.*

## Technical Name: Host
- **Part of Speech:** Noun
- **Definition:** The machine that runs adacovex. The host is separate from
  the target project that adacovex assesses.
- **Approved Form:** Host (singular), Hosts (plural)
- **Do Not Use:** Local machine, Computer, System (when the host is meant)
- **Correct Example:** *The tool probes the **host** CPU count.*
- **Incorrect Example:** *The tool probes the local machine CPU count.*

## Technical Name: Target
- **Part of Speech:** Noun
- **Definition:** The project that adacovex assesses. The `--target` flag
  points at the target project.
- **Approved Form:** Target (singular), Targets (plural)
- **Do Not Use:** Project (when the assessed project is meant), Subject,
  Audited tree
- **Correct Example:** *The **target** is a SPARK project in git.*
- **Incorrect Example:** *The subject is a SPARK project in git.*
