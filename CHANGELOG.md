## 0.3.1
- Revert to fuzzaldrin from fuzzaldrin-plus for `:` matching is better for CoffeeScript, not investigated deep.

## 0.3.0
- New: New config param `clearSearchTextOnEverySearch` to clear search text on every search. #7.

## 0.2.0
- Now use atom's overlay decoration instead of direct pixel calculation.
- Refactoring: Rewritten 30% of whole code.
- New: #4 Support space separated multi search keyword. right keyword is searched from line where left keyword was found.
- New: Use fuzzaldrin-plus but not much difference for behavior.
- Breaking: Remove `autoLand`, `minimumInputLength` configuration parameter.
- Remove dependency of atom-config-plus module.

## 0.1.17
- Fix #10 Setting view cannot accessible from Atom v1.4.0.
- Fix #11 Throw error when search single occurrence with autoLand is enabled.

## 0.1.16 - FIX
- Just for releasing v0.1.14. fix minor mistake for releasing version.

## 0.1.14 - FIX
- FIX: findFoldMarkers need explicit filter query object from Atom 1.3.0. #9

## 0.1.13 - Improve
- Now hover indicator follow scroll. Useful when quickly visit, scroll then cancel.
  Until this improvement hover sticked absolute pixel position and disturbed your sight.

## 0.1.12 - Improve
- Update readme to follow vim-mode's rename from command-mode to normal-mode
- Refactoring.
- FIX historyManager, get 'next' was not return correct entry.

## 0.1.11 - Improve
- If match is under cursor, get next entry #4.

## 0.1.10 - Search history support.
- Search history #4.
- Set cursor word as search.

## 0.1.9 - Refactoring
- Cleanup code.
- Change base style and add style change example in README.md.

## 0.1.8 - Refactoring
- Remove unnecessary `UI::setDirection` method

## 0.1.7 - Improve
- `selectToBufferPosition` if start with selection.

## 0.1.6 - FIX
- [FIX] land() throw error if there is no matches when confirmed().

## 0.1.5 - Improve
- Better fold restore.
- Refactored, improve readability.

## 0.1.4 - Improve
- [FIX] Incorrect flash screen area when fold exists.
- Now restore fold if canceled.

## 0.1.3 - Improve
- Doc fix `lazy-motion:search-forward` should be `lazy-motion:forward`.
- Modify CSS padding on input panel.

## 0.1.2 - Refactoring
- Cleanup code, fix minor bug.
- Change default: Enable hover indicator by default.

## 0.1.1 - Rename package name
- Rename package name from rapid-motion to lazy-motion.

## 0.1.0 - First Release
