# Repository conventions

- Use English for code identifiers, comments, source strings, documentation, diagrams, public screenshots, commit messages, pull requests, and other GitHub content.
- Keep translated user-facing content in localization resources. Language names may use their native spelling in the language picker. The application supports English and French; this does not change the repository's English documentation policy.
- Preserve the Sillage product name.
- Make regular, focused commits as each coherent change is ready, using Conventional Commits in English (for example, feat(settings): add language selection or docs(readme): simplify getting started). Keep feature work, fixes, and documentation changes separate when practical.
- Keep the README short: features, requirements, getting started, and links to detailed documentation.
- Keep the AI-generated disclosure as a compact linked logo in the README header. Do not add explanatory AI paragraphs there unless explicitly requested.
- Add only accurate badges. Never claim passing CI, test coverage, a release, or a license without corresponding configuration and evidence.
- Never commit credentials, personal data, local machine paths, audio recordings, diagnostic files, build caches, signing material, or application bundles.
- Keep runtime dependencies limited to system frameworks unless a new dependency is justified.
- Use scripts/build-app.sh and scripts/test.sh for app changes. For documentation-only changes, check links, assets, and rendering instead of running unrelated tests.
