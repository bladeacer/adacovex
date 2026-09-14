# STE100 Technical Names: proof and compliance terms

The **proof and compliance** terms of the [STE100 Technical Names]
(index.md) dictionary.  These terms name the verification,
requirement, and safety-standard concepts of the adacovex domain.

## Technical Name: Verification Condition (VC)
- **Part of Speech:** Noun
- **Definition:** A logical statement that a proof tool must prove. gnatprove
  reports VCs per check category, for example flow, run-time, and assertion.
- **Approved Form:** Verification Condition (singular), Verification
  Conditions (plural), VC (singular), VCs (plural)
- **Do Not Use:** Proof goal, Proof obligation, Test case
- **Correct Example:** *The proof proves all 722 **VCs**.*
- **Incorrect Example:** *The proof proves all 722 proof obligations.*

## Technical Name: Assertion
- **Part of Speech:** Noun
- **Definition:** A user-written property that must hold at a point in the
  program. In Ada, an assertion is a `pragma Assert`.
- **Approved Form:** Assertion (singular), Assertions (plural)
- **Do Not Use:** Assumption, Check, Statement of truth
- **Correct Example:** *The **assertion** proves that the index is in range.*
- **Incorrect Example:** *The assumption proves that the index is in range.*

## Technical Name: Proof
- **Part of Speech:** Noun
- **Definition:** A formal demonstration, produced by a proof tool, that a
  property of the program holds.
- **Approved Form:** Proof (singular), Proofs (plural)
- **Do Not Use:** Verification (when the proof result is meant),
  Demonstration
- **Correct Example:** *The **proof** has zero unproved verification conditions.*
- **Incorrect Example:** *The verification has zero unproved verification conditions.*

## Technical Name: SPARK Level
- **Part of Speech:** Noun
- **Definition:** One of the five SPARK assurance levels: Stone, Bronze,
  Silver, Gold, and Platinum. Each level builds on the previous one.
- **Approved Form:** SPARK Level (singular), SPARK Levels (plural)
- **Do Not Use:** Grade (for the concept), Assurance level (when SPARK is
  meant)
- **Correct Example:** *The target reaches **Platinum**, the highest SPARK level.*
- **Incorrect Example:** *The target reaches Platinum, the highest grade.*

## Technical Name: Coverage
- **Part of Speech:** Noun
- **Definition:** The percentage of subprograms that have a docstring, out of
  all subprograms in the scanned source tree.
- **Approved Form:** Coverage (no plural)
- **Do Not Use:** Completion rate, Documentation rate, Percentage documented
- **Correct Example:** *The docstring **coverage** is 100 per cent.*
- **Incorrect Example:** *The completion rate is 100 per cent.*

## Technical Name: Design Assurance Level (DAL)
- **Part of Speech:** Noun
- **Definition:** One of the five DO-178C levels (A to E) that classify the
  severity of a failure condition. DAL A is the most severe.
- **Approved Form:** Design Assurance Level (singular), DAL (abbreviation)
- **Do Not Use:** Safety level, Integrity level
- **Correct Example:** *adacovex assesses compliance at **DAL C** for this target.*
- **Incorrect Example:** *adacovex assesses compliance at safety level C for this target.*

## Technical Name: ASIL
- **Part of Speech:** Noun
- **Definition:** An Automotive Safety Integrity Level from ISO 26262. The
  levels run from QM to ASIL D. ASIL D is the highest hazard level.
- **Approved Form:** ASIL (no plural)
- **Do Not Use:** Automotive safety level, ASIL level (redundant)
- **Correct Example:** *The target achieves **ASIL B** under ISO 26262.*
- **Incorrect Example:** *The target achieves automotive safety level B under ISO 26262.*

## Technical Name: High-Level Requirement (HLR)
- **Part of Speech:** Noun
- **Definition:** A requirement that states what the software must do, at the
  system or software level, without implementation detail.
- **Approved Form:** High-Level Requirement (singular), HLR (abbreviation)
- **Do Not Use:** Top-level requirement, System requirement (when the HLR
  index is meant)
- **Correct Example:** *Every **HLR** traces to a source tag.*
- **Incorrect Example:** *Every top-level requirement traces to a source tag.*

## Technical Name: Low-Level Requirement (LLR)
- **Part of Speech:** Noun
- **Definition:** A requirement that states how the software implements a
  high-level requirement, with implementation detail.
- **Approved Form:** Low-Level Requirement (singular), LLR (abbreviation)
- **Do Not Use:** Implementation requirement, Detail requirement
- **Correct Example:** *The **LLR** describes how the parser implements the HLR.*
- **Incorrect Example:** *The detail requirement describes how the parser implements the HLR.*

## Technical Name: Traceability
- **Part of Speech:** Noun
- **Definition:** The documented mapping between requirements and the source
  code that implements them.
- **Approved Form:** Traceability (no plural)
- **Do Not Use:** Linkage, Mapping (when the concept of traceability is
  meant)
- **Correct Example:** *The report shows the **traceability** from each HLR to its source tags.*
- **Incorrect Example:** *The report shows the linkage from each HLR to its source tags.*

## Technical Name: Assessment
- **Part of Speech:** Noun
- **Definition:** The process of evaluating a target project against the
  criteria of a standard or a gate.
- **Approved Form:** Assessment (singular), Assessments (plural)
- **Do Not Use:** Analysis (when the evaluation run is meant), Review
- **Correct Example:** *The **assessment** runs without modifying the target tree.*
- **Incorrect Example:** *The analysis runs without modifying the target tree.*

## Technical Name: Compliance
- **Part of Speech:** Noun
- **Definition:** Conformance of the target with the criteria of a standard,
  for example DO-178C or ISO 26262.
- **Approved Form:** Compliance (no plural)
- **Do Not Use:** Adherence, Conformance (when the DO-178C result is meant)
- **Correct Example:** *The target shows **compliance** with DO-178C at DAL C.*
- **Incorrect Example:** *The target shows adherence with DO-178C at DAL C.*
