# Performance Measurement Lab

Лабораторна робота з аналізу продуктивності множення квадратних матриць у Windows.

Автор: Кашинський Владислав, ТТП-32.

## Варіанти програми

- `matmul_baseline`: збірка MSVC з `/Od`, скалярне ядро.
- `matmul_optimized`: збірка MSVC з `/O2`, `/arch:AVX2` та FMA.

Обидві програми виконують однакове множення матриць і друкують checksum.

## Збірка

Потрібна Visual Studio 2026 з компонентом Desktop development with C++.

```powershell
.\scripts\build.ps1
```

Результат збірки знаходиться у `build\bin\Release`. Файл `Open-Project.cmd` збирає проєкт і відкриває створене рішення Visual Studio.

## Запуск

```powershell
.\build\bin\Release\matmul_baseline.exe 768 6
.\build\bin\Release\matmul_optimized.exe 768 6
.\scripts\verify.ps1
```

## Вимірювання

```powershell
.\scripts\measure.ps1
.\scripts\vtune.ps1 -Analysis hotspots
.\scripts\vtune.ps1 -Analysis uarch
.\scripts\energy.ps1
```

Для Flame Graph використовується Visual Studio Performance Profiler з інструментом CPU Usage. Числові результати збережені у каталозі `results`, а звіт знаходиться у `report\main.tex`.

