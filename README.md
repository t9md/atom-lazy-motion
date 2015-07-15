# lazy-motion


Rapid cursor positioning with **fuzzy**, **lazy** search.

![gif](https://raw.githubusercontent.com/t9md/t9md/3379ed41ea6fd3725245f5d37b3bb36f7e9b0683/img/atom-lazy-motion.gif)

# Feature

* Search word within buffer with fuzzy search by [fuzzaldrin](https://github.com/atom/fuzzaldrin).
* Display `current / total` match count in input panel and hover indicator.
* Incrementally scroll(visit) to matched position.
* Don't change cursor position unless you confirm(important for [cursor-history](https://atom.io/packages/cursor-history) like pakcage).
* Differentiate color for top(blue) and bottom(red) entry of matches.
* Highlight original cursor position while searching and flash current matching.
* Flash screen if no match.

# Why

Lets say you are editing over 200 lines of CoffeeScript file.  
And you want to go to line where code `@container?.destroy()` is to change it.  

With lazy-motion, you can reach target in following way.

1. Invoke `lazy-motion:forward` from keymap.
2. Input `c?d` to input panel.
3. `core:confirm` to land or `core:cancel` to cancel.

## Other examples
* `ca)` to reach line containing `cancel()`.
* `gemade` to reach line containing `@flashingDecoration?.getMarker().destroy()`.

Like the example above you can reach target position with very lazy and fuzzy key type.

## Why *label jump* approach not worked for me.

Until now I released [vim-smalls](https://github.com/t9md/vim-smalls/blob/master/README-JP.md) and its [Atom port](https://github.com/t9md/atom-smalls).  

And also hacked [jumpy](https://github.com/t9md/jumpy) and [vim-easymotion](https://github.com/t9md/vim-easymotion) as exercise to create  smalls.  

But as for me this *label jump* system not work, I couldn't adapt to it.  

The reason is simple.  

The *label jump* constrains me to enter label precisely which result in my focus(or zone or flow) lost.  

Of course this *label jump* packages let me reach target position with minimum key typing.  
But in my opinion, its only good for demonstration.

In real world coding, the **brain context switch** the *label jump* enforces is **too expensive** to use on a daily basis.  

# Commands

### atom-text-editor
* `lazy-motion:forward`: Search forward.
* `lazy-motion:backward`: Search backward.
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
  'ctrl-s':     'lazy-motion:forward'
  'ctrl-cmd-r': 'lazy-motion:backward'

'atom-text-editor.lazy-motion':
  ']': 'lazy-motion:forward'
  '[': 'lazy-motion:backward'
```

* Emacs user

```coffeescript
'atom-text-editor':
  'ctrl-s': 'lazy-motion:forward'
  'ctrl-r': 'lazy-motion:backward'

'.platform-darwin atom-text-editor.lazy-motion':
  'ctrl-s': 'lazy-motion:forward'
  'ctrl-r': 'lazy-motion:backward'
  'ctrl-g': 'core:cancel'
```

* My setting

```coffeescript
'atom-text-editor.vim-mode.command-mode':
  's': 'lazy-motion:forward'

'.platform-darwin atom-text-editor.lazy-motion':
  'ctrl-u': 'editor:delete-to-beginning-of-line'
  ']':      'lazy-motion:forward'
  '[':      'lazy-motion:backward'
  ';':      'core:confirm'
  'ctrl-g': 'core:cancel'
```

# Change Style

Style used in lazy-motion is defined in [main.less](https://github.com/t9md/atom-lazy-motion/blob/master/styles/main.less).  
You can change style bye overwriting these style in your `style.css`.  

e.g.

```less
atom-text-editor::shadow {
  // Change border
  .lazy-motion-match.top .region {
    border-width: 1px;
  }
  .lazy-motion-match.bottom .region {
    border-width: 1px;
  }
  .lazy-motion-match.current .region {
    border-width: 2px;
  }
  // Change hover label
  .lazy-motion-hover {
    color: @text-color-selected;
    background-color: @syntax-selection-color;
    &.top {
      background-color: @syntax-color-renamed;
    }
    &.bottom {
      background-color: @syntax-color-removed;
    }
  }
}
```


# Limitation

Slow in large buffer.  

Tried to pre-generate candidate by `observeTexitEditors` but its not work.  
Editing buffer with huge merkers is very slow.  
So create marker on `lazy-motion` start and destroy on finish is better than that.  

# Language specific `wordRegExp` configuration.

You can specify `wordRegExp` configuration per language.  

See [Scoped Settings, Scopes and Scope Descriptors](https://atom.io/docs/latest/behind-atom-scoped-settings-scopes-and-scope-descriptors) and [API/Config](https://atom.io/docs/api/latest/Config) for details.

* in your `config.cson`.
```coffeescript
"*": # This is global scope. Used as default.
  # <snip>
  "lazy-motion":
    wordRegExp: 'xxxx'
  # <snip>
".go.source": # This is Go specific,
  "lazy-motion":
    wordRegExp: 'xxxx'
```

# TODO
- [x] Restore fold if canceled.
- [x] Support language specific `wordRegExp` configuration.
- [x] Show hover indicator to inform `current / total`.
- [x] `AutoLand` if there is no other candidate.
