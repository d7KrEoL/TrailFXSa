## The effects.fxp file
This file contains definitions of effects used by the game. Because the script does not work with memory directly, the effects used by the script must be added to `effects.fxp`. The required effects are:
- trail_red_long
- trail_green_long
- trail_blue_long
- trail_sky_long
- trail_black_long
- trail_purp_long
- trail_red_short
- trail_green_short
- trail_blue_short
- trail_sky_short
- trail_black_short
- trail_purp_short

## Installation
To add the effects listed above, copy the contents of the provided [effects.fxp](./effects.fxp) file and paste it at the very end of your game's `models/effects.fxp`, before the line `FX_PROJECT_DATA_END:`, as shown in the image:

![Picture](../images/ChangeEffectsFXP.png)

## Editing effects
The file is a sequential description of an effect composed of primitives (particles) and contains the following blocks:

- FX_SYSTEM_DATA — header for each effect
- General information block: `FILENAME` - `NUM_PRIMS`
- FX_PRIM_BASE_DATA — base data for the graphical primitive
- FX_INFO_EMRATE_DATA — emission rate / particle spawn frequency
- FX_INFO_EMSPEED_DATA — initial particle speed
- FX_INFO_EMANGLE_DATA — spread/angle of emitted particles
- FX_INFO_EMLIFE_DATA — particle lifetime
- FX_INFO_EMROTATION_DATA — initial rotation angle
- FX_INFO_ROTSPEED_DATA — rotation speed
- FX_INFO_FRICTION_DATA — friction / medium resistance
- FX_INFO_FORCE_DATA — external forces: gravity, wind
- FX_INFO_SIZE_DATA — particle size
- LOD (Level of Detail):
    - LODSTART — start distance for rendering
    - LODEND — end distance for rendering
- FX_PRIM_EMITTER_DATA — emitter (source) data for the primitive

### Changing color
To change an effect's color, find the effect block and its `FX_INFO_COLOURBRIGHT_DATA` section, then edit the following sub-blocks:

```c
RED->FX_KEYFLOAT_DATA->VAL // (2 values)
GREEN->FX_KEYFLOAT_DATA->VAL // (2 values)
BLUE->FX_KEYFLOAT_DATA->VAL // (2 values)
ALPHA->FX_KEYFLOAT_DATA->VAL // (2 values)
```

> [!TIP]
> #### Why 2 values:
> The file specifies values for different stages of a particle's life: from birth at TIME: 0.000 to death at TIME: 1.000

Color components are fractional numbers from 0.000 to 255.000, where 255 is the maximum brightness for an RGBA component.

### Example:
```bash
FX_INFO_COLOURBRIGHT_DATA:
TIMEMODEPRT: 1
RED:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 2
FX_KEYFLOAT_DATA:
TIME: 0.000
VAL: 255.000 # Red amount at birth
FX_KEYFLOAT_DATA:
TIME: 0.150 
VAL: 255.000 # Red amount at time 0.150
GREEN:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 2
FX_KEYFLOAT_DATA:
TIME: 0.000
VAL: 0.000 # Green amount at birth
FX_KEYFLOAT_DATA:
TIME: 0.150
VAL: 0.000 # Green amount at time 0.150
BLUE:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 2
FX_KEYFLOAT_DATA:
TIME: 0.000
VAL: 0.000 # Blue amount at birth
FX_KEYFLOAT_DATA:
TIME: 0.150
VAL: 0.000 # Blue amount at time 0.150
ALPHA:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 2
FX_KEYFLOAT_DATA:
TIME: 0.000
VAL: 255.000 # Opacity at birth
FX_KEYFLOAT_DATA:
TIME: 0.150
VAL: 50.000 # Opacity at time 0.150
BIAS:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 2
FX_KEYFLOAT_DATA:
TIME: 0.000
VAL: 0.000  # Color variance at birth
FX_KEYFLOAT_DATA:
TIME: 0.150
VAL: 0.100 # Color variance at time 0.150 (value ±0.100)
```

### Effect disappearance, performance
The game has a global limit on the number of simultaneously existing particles. Once this limit is exceeded, new particles will not be created or rendered until older ones disappear. If you frequently see the smoke stop rendering, reduce the emission rate in `FX_INFO_EMRATE_DATA` or shorten particle life in `FX_INFO_EMLIFE_DATA`.

### Important values in `FX_INFO_EMRATE_DATA`
```bash
FX_INFO_EMRATE_DATA:
RATE:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 2
FX_KEYFLOAT_DATA:
TIME: 0.000
# Number of particles spawned per unit time. Higher value -> denser smoke,
# but you must reduce lifetime accordingly (in FX_INFO_EMLIFE_DATA)
VAL: 50.000 # <---
FX_KEYFLOAT_DATA:
TIME: 0.100
VAL: 0.000
```

### Important values in `FX_INFO_EMLIFE_DATA`
```bash
FX_INFO_EMLIFE_DATA:
LIFE:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 1
FX_KEYFLOAT_DATA:
TIME: 0.000
# Particle lifetime. The higher the value, the more sparse you must make the smoke
VAL: 15.000 # <---
BIAS:
FX_INTERP_DATA:
LOOPED: 0
NUM_KEYS: 1
FX_KEYFLOAT_DATA:
TIME: 0.000
VAL: 0.000
```