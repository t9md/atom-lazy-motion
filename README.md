# rapid-motion

Rapid cursor positioning with **fuzzy**, **lazy** search.

![gif](https://raw.githubusercontent.com/t9md/t9md/c944fc38bbc8e5f5a16b03616e127efc66911a1c/img/atom-rapid-motion.gif)

# Feature

* Search word within buffer with fuzzy search by [fuzzaldrin](https://github.com/atom/fuzzaldrin).
* Display matching count and `current / total` match in input panel and hover indicator(hover indicator is disabled by default).
* Incrementally scroll(visit) to matched position.
* Don't change cursor position unless you confirm(important for [cursor-history](https://atom.io/packages/cursor-history) like pakcage).
* Differentiate color for top(blue) and bottom(red) entry of matches.
* Highlight original cursor position while searching and flash current matching.
* Flash screen if no match.

# Why

Lets say you are editing over 200 lines of CoffeeScript file.  
And you want to go to line where code `@container?.destroy()` is to modify it.  

By the power of rapid-motion, you can reach target by following way.

1. Invoke `rapid-motion:forward` from keymap.
2. input `c?d` to input panel.
3. `core:confirm` to land or `core:cancel` to cancel.

## other example
* `ca)` to reach lines containing `cancel()`.
* `gemade` to reach `@flashingDecoration?.getMarker().destroy()`.

Like the example above you can reach target position with very lazy and fuzzy typing.

## Why *label jump* approach not worked for me.
Until now I created [vim-smalls](https://github.com/t9md/vim-smalls/blob/master/README-JP.md) and its [Atom port](https://github.com/t9md/atom-smalls).  

And hacked [jumpy](https://github.com/t9md/jumpy) and [vim-easymotion](https://github.com/t9md/vim-easymotion) as excercise to create  smalls.  

But at least for me this *label jump* system not work, I coudn't addapt to it.  

The reason is simple.  

The *label jump* constrain me to enter label precisely which result in my focus(or zone or flow) lost.  

Of course this *label jump* packages let me reach target position with minimum key type.  
But ,in my opinion, its good for demonstration

In real world coding, the **brain context switch** the *label jump* enforces is **too expensive** to use on a daily basis.  

# Commands

### atom-text-editor
* `rapid-motion:forward`: Search forward.
* `rapid-motion:backward`: Search backward.
* `core:confirm`: confirm.
* `core:cancel`:  cancel.

*NOTE: Search always wrap from end-to-top or top-to-end.*

# Configuration

* `autoLand`: Automatically land(confirm) if there is no other candidates.
* `minimumInputLength`: Search start only when input length exceeds this value.
* `wordRegExp`: Used to build candidate word list.
* `showHoverIndicator`: Show hover indicator while searching.

# Keymap

No keymap by default.  
You need to set your own keymap in `keymap.cson`.

```coffeescript
'atom-text-editor':
  'ctrl-s':     'rapid-motion:forward'
  'ctrl-cmd-r': 'rapid-motion:backward'

'atom-text-editor.rapid-motion':
  ']': 'rapid-motion:forward'
  '[': 'rapid-motion:backward'
```

* Emacs user

```coffeescript
'atom-text-editor':
  'ctrl-s': 'rapid-motion:forward'
  'ctrl-r': 'rapid-motiion:backward'

'.platform-darwin atom-text-editor.rapid-motion':
  'ctrl-s': 'rapid-motion:forward'
  'ctrl-r': 'rapid-motion:backward'
  'ctrl-g': 'core:cancel'
```

* My setting

```coffeescript
'atom-text-editor.vim-mode.command-mode':
  's': 'rapid-motion:search-forward'

'.platform-darwin atom-text-editor.rapid-motion[mini]':
  ']':      'rapid-motion:forward'
  '[':      'rapid-motion:backward'
  ';':      'core:confirm'
  'ctrl-g': 'core:cancel'
```

# Limitation

Slow in large buffer.  

Tried to pre-generate candidate by `observeTexitEditors` but its not work.  
Editing buffer with huge merkers is very slow.  
So create marker on `rapid-motion` start and destroy on finish is better than that.  

# Language specific `wordRegExp` configuration.

You can specify `wordRegExp` configuration per language.  

See [Scoped Settings, Scopes and Scope Descriptors](https://atom.io/docs/latest/behind-atom-scoped-settings-scopes-and-scope-descriptors) and [API/Config](https://atom.io/docs/api/latest/Config) for details.

* in your `config.cson`.
```coffeescript
"*": # This is global scope. Used as default.
  # <snip>
  "rapid-motion":
    wordRegExp: 'xxxx'
  # <snip>
".go.source": # This is Go specific,
  "rapid-motion":
    wordRegExp: 'xxxx'
```

# TODO
- [x] Support language specific `wordRegExp` configuration.
- [x] Show hover indicator to inform `current / total`.
- [x] `AutoLand` if there is no other candidate.
