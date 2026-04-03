# Repository Guidelines

## Security

- Never read or write to .env file
- Never read or write files outside of this repo without my permission

## Code Guidelines

- KISS
- DRY
- Generally prefer functional programming
- Write modular, reusable code
- Prefer to have ONE main function/class per file of the same name
- Include types whenever possible; try to emulate typescript practices
- Write docstrings for all functions and classes

## Command Short Codes

### Git Assist

- When the prompt is sth like `git assist` or even just `ga` with no other context, then what I am asking for is: suggest a strong git-commit message that summarizes the changes that have been made on this branch since the last commit, with 10 words max.

- When `git assist branch`, I want a single message of 10 words max to summarize all of the changes made on the present branch relative to main. I will use that message to squash this branch onto main and make a single commit representing that branch.

### Misc Short Codes

- "ABA". When the final think written in a chat is "ABA" or "aba", it means "Answer Before Acting". In other words, do NOT edit any files, just respond to what was just written!
