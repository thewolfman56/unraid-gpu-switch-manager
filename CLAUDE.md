# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

[Add project description here - what this project does, its main purpose, and key goals]

## Development Commands

### Building
```bash
# Add build commands here
```

### Testing
```bash
# Add test commands here
```

### Linting/Formatting
```bash
# Add linting/formatting commands here
```

### Running
```bash
# Add run commands here
```

## Architecture

[Add high-level architecture description here - focus on the "big picture" that requires reading multiple files to understand]

## Key Patterns and Conventions

[Add important patterns, conventions, and architectural decisions that future Claude instances should know]

## Project-Specific Notes

[Add any project-specific context, constraints, or important information]

## Memory Management Instructions

### Proactive Memory Storage (mem-zero)
You are equipped with mem-zero for persistent memory. Do not wait for explicit user requests to store information; manage memory autonomously using these rules:

* **Search First:** At the start of every conversation, search mem-zero for prior context.
* **Store Decisions, Not Play-by-Play:** Record architectural choices and reasoning. Avoid line-by-line change logs.
* **Store Dead Ends:** Document failed approaches to prevent repeating mistakes.
* **Quality Over Quantity:** Use complete, self-contained statements. One memory per logical decision.
* **Let the Code Speak:** Store the "why," not the "what." The codebase is the authority for signatures and structure.
* **Capture Context & Preferences:** Store patterns, conventions, and workflow tools automatically.
* **Technical Debt & Feedback:** Track refactoring needs and permanent user corrections.
