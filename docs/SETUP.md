# Окружение

Что установлено на рабочей машине и где лежит. Актуально на 1 сентября 2026.

## Движок

**Godot 4.7.2 в сборке GodotSteam 4.22** — `/Applications/GodotSteam.app`

Это пересобранный движок со Steamworks 1.65 внутри, а не аддон. Аддонной
версии больше нет: GodotSteam слили модуль и GDExtension в одну ветку, и
поставляется теперь только собранный редактор.

```bash
/Applications/GodotSteam.app/Contents/MacOS/Godot --version
# 4.7.2.stable.custom_build
```

Проверка, что Steamworks на месте:

```bash
echo 'extends SceneTree
func _init():
	print(ClassDB.class_exists("Steam"))
	quit()' > /tmp/c.gd
/Applications/GodotSteam.app/Contents/MacOS/Godot --headless --script /tmp/c.gd
# true
```

Universal binary, на Apple Silicon идёт нативно.

**Стоковый Godot** из Homebrew удалён 1 сентября 2026 — в нём нет Steamworks,
и для этого проекта он бесполезен. Если понадобится для сторонних
экспериментов: `brew install --cask godot`.

## Шаблоны экспорта

```
~/Library/Application Support/GodotSteam/export_templates/4.22-g472/
  macos/macos.zip
  win64/  win32/  linux64/  linuxarm64/
```

Это **кастомные шаблоны**: они не кладутся в стандартную папку
`export_templates` движка, а прописываются вручную в поле Custom Template
каждого пресета экспорта. Рядом с каждым шаблоном лежит библиотека Steam API
для своей платформы — её кладут рядом с готовым билдом.

832 МБ. В репозиторий не входят намеренно.

## Редактор кода

**Zed** — `/Applications/Zed.app`, ставился через `brew install --cask zed`.
Нативный под Apple Silicon, лёгкий по памяти, что важно на 8 ГБ рядом
с открытым Godot.

## Репозиторий

- Локально: `/opt/services/lomka`
- Удалённо: https://github.com/e2or28/lomka — приватный

## Ограничения машины

MacBook M1, 8 ГБ. Память — узкое место. Godot и тяжёлые приложения
одновременно держать не стоит. Экспорт и запекание — разовые операции,
но память в них улетает.
