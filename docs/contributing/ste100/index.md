# STE100 Technical Names for adacovex

ASD-STE100 Simplified Technical English (Section 1, "Words") defines a
controlled vocabulary. Most words in that vocabulary are standard STE words.
Some concepts have no accurate standard STE word. For those concepts, the
project approves a **Technical Name (TN)**.

A Technical Name is a non-STE word that the project explicitly approves. The
project approves it because no standard STE word describes the concept with
the same precision. A TN has a single mandatory part of speech and a defined
scope. The scope is restricted to the software domain of adacovex.

This page is the controlled list of Technical Names for adacovex. Writers of
user documentation, API documentation, docstrings, and changelogs must use
these terms as defined here. If you need a term that is not in this list,
add it to the list first, then use it.

## Categories for Ada Technical Names

Group the Technical Names by their structural role in the software domain.
Each category has its own lexicon page:

- **Ada Language Constructs** -- specific language features that generic
  English words cannot replace without losing technical precision. For
  example, pragma, discriminant, rendezvous, task. Lexicon:
  [Ada language constructs](ada-terms.md).
- **Proof and compliance terms** -- the verification, requirement, and
  standard concepts of the adacovex domain. For example, verification
  condition, high-level requirement, design assurance level. Lexicon:
  [proof and compliance terms](proof-terms.md).
- **Tooling and workflow terms** -- the commands, flags, files, and
  artefacts of the tool. For example, subcommand, flag, badge, result
  cache. Lexicon: [tooling and workflow terms](tooling-terms.md).
- **Hardware and System Entities** -- physical components, buses, or
  microarchitectures that the Ada code interacts with. For example, CPU
  core. Lexicon: [hardware and system entities](entities.md).
- **Code Identifier Names** -- exact package, type, subtype, subprogram,
  tool, and file names as declared in the source code or used by the
  toolchain. For example, `System.Storage_Elements`, `gnatprove`, `Alire`.
  Lexicons: [tools and files](identifiers.md) and
  [reports and concepts](concepts.md).

## Required data fields for each entry

ASD-STE100 requires strict controls over how approved words are documented.
Every Technical Name in this dictionary has all five fields:

| Field | Description | Example |
| --- | --- | --- |
| **Approved Word (TN)** | The exact word or identifier. | **Pragma** |
| **Part of Speech** | STE permits a word as only *one* part of speech (Noun, Verb, Modifier). | Noun |
| **Approved Meaning / Definition** | Clear, unambiguous definition restricted to the adacovex domain. | A compiler directive in the Ada programming language. |
| **Non-Approved Alternatives** | Terms that authors must NOT use instead of this TN. | *Compiler directive*, *Annotation* |
| **Example Sentence** | A compliant STE sentence demonstrating usage. | *Add the **pragma** to the top of the package specification.* |

## Key rules for Ada Technical Names

- **Nouns stay nouns.** Technical Names are almost always approved as Nouns
  or Modifiers. Never approve a code action as a verb if a standard STE verb
  exists. For example, use the approved verb *Calculate* instead of creating
  a TN verb *Compute*.
- **Exact case matching.** Treat Ada identifiers (`Pascal_Case` or
  `UPPER_CASE`) as literal Technical Names. Use the exact casing in
  documentation. This rule distinguishes language concepts from code
  entities.
- **No synonyms.** If the project approves *Task* as a TN for an Ada
  concurrent execution unit, do not use words like *Thread*, *Process*, or
  *Job* for that concept.
- **One part of speech per word.** A TN is a Noun or a Modifier, never both.
  When you need the action, use the standard STE verb that matches the noun
  form.

## Standard entry template

```markdown
### Technical Name: Task
- **Part of Speech:** Noun
- **Category:** Ada Language Construct
- **Definition:** A standalone unit of concurrent execution in Ada.
- **Approved Form:** Task (singular), Tasks (plural)
- **Do Not Use:** Thread, Process, Job, Execution Unit
- **Correct Example:** *The main **task** waits for the sensor **task** to finish.*
- **Incorrect Example:** *The main process waits for the sensor thread to complete.*
```
