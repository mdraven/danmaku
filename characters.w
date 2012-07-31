
===========================================================

Персонажи.

Теперь стоит подумать о игровых персонажах.
Они должны иметь возможность свободно перемещаться по игровому полю и исчезать когда им захочется.

-Должны ли пули и снаряды хранится с игровыми персонажами в одном списке?
Пули не возвращают дескрипторы(их слишком много). Этим они отличаются от персонажей.

Пули будут иметь специальную функцию, которая принимает прямоугольник у персонажа и сообщает было пересечение
или нет.
Возможен и обратный подход, когда персонаж имеет функцию, а пуля прямоугольник пересечения, но в таком
случае мы не сможем отображать снизу области поражения вражеских персонажей.
Функция перемещения, её вызов двигает снаряд на итерацию.


@o characters.h @{
@<License@>

#ifndef __CHARACTERS_H__
#define __CHARACTERS_H__

#include <stdint.h>

@<Character public macros@>
@<Character public structs@>
@<Character public prototypes@>

#endif /* __CHARACTERS_H__ */
@}


Опишем структуру персонажа:
@d Character public structs @{
#define CHARACTER_NUM_ARGS 18

struct CharacterList {
    struct CharacterList *prev;
    struct CharacterList *next;
    struct CharacterList *pool;
    int hp;
    int x;
    int y;
    int character_type;
    int radius;
    intptr_t args[CHARACTER_NUM_ARGS];
};

typedef struct CharacterList CharacterList;
@}
О структуре:
  hp - количество жизней персонажа
  x, y - координаты
  character_type - тип персонажа, основной параметр для диспетчеризации
  radius - радиус хитбокса
  args - прочие аргументы
  CHARACTER_NUM_ARGS - число агрументов args

Для CharacterList используется переменная args фиксированного размера для того, чтобы
  избежать фрагментации памяти. Блоки одинакового размера при удалении можно хранить в одном
  списке и при необходимости ипользовать повторно без написания сложного аллокатора.

Для удобства доступа к названию аргумента введём макрос:
@d Character public macros @{
#define CMA(character_name, arg_name)  character_##character_name##_##arg_name##_arg
@}
CharacterMacroArgument

@o characters.c @{
@<License@>

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>

#include "characters.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"
#include "bullets.h"
#include "timers.h"
#include "dlist.h"
#include "danmakufu.h"

@<Character private macros@>
@<Character private structs@>
@<Character private prototypes@>
@<Character functions@>
@}

Список персонажей:
@d Character public structs @{
extern CharacterList *characters;
@}

@d Character private structs @{
CharacterList *characters;
@}

Пул свободных элементов для персонажей и удалённых персонажей:
@d Character private structs
@{static CharacterList *pool;

static CharacterList *pool_free;
static CharacterList *end_pool_free;
@}
end_pool_free - ссылка на последний элемент pool_free

CHARACTER_ALLOC - аллоцируется слотов для персонажей в самом начале
CHARACTER_ADD - добавляется при нехватке
@d Character private macros @{
#define CHARACTER_ALLOC 150
#define CHARACTER_ADD 50
@}

Функция для возвращения выделенных слотов обратно в пул:
@d Character functions @{
static void character_free(CharacterList *character) {
    if(character == characters)
        characters = characters->next;

    if(pool_free == NULL)
        end_pool_free = character;

    dlist_free((DList*)character, (DList**)(&pool_free));
}
@}
Если освобождаем слот в самом начале списка characters, то первым становится
    второй слот для персонажа в списке.
Удаляем в специальный пул(pool_free) так как в том же цикле ячейка
    может быть использована снова и тогда ->next и ->prev будут изменены.
Устанавливаем указатель на последний элемент пула end_pool_free, чтобы потом
    легче было соединить с pool(используется то, что dlist_free добавляет элементы
    в начало pool_free).

Соединить pool_free с pool:
@d Character functions @{
static void character_pool_free_to_pool(void) {
    if(end_pool_free == NULL)
        return;

    end_pool_free->pool = pool;
    pool = pool_free;

    pool_free = NULL;
    end_pool_free = NULL;
}
@}
Соединяет односвязный список pool_free с pool.
Надо вызывать после for обходящих список characters, но думаю что достаточно
    вызывать только в ai_control.

character_get_free_cell - функция возвращающая свободный дескриптор:
@d Character functions @{
static CharacterList *character_get_free_cell(void) {
    if(pool == NULL) {
        int k = (characters == NULL) ? CHARACTER_ALLOC : CHARACTER_ADD;
        int i;

        pool = malloc(sizeof(CharacterList)*k);
        if(pool == NULL) {
            fprintf(stderr, "\nCan't allocate memory for characters' pool\n");
            exit(1);
        }

        for(i = 0; i < k-1; i++)
            pool[i].pool = &(pool[i+1]);
        pool[k-1].pool = NULL;
    }

    characters = (CharacterList*)dlist_alloc((DList*)characters, (DList**)(&pool));

    return characters;
}
@}

Типы персонажей:
@d Character public structs @{
enum {
    character_reimu, character_marisa, @<Character types@>
};
@}

Рейму:
@d Character functions @{
CharacterList *character_reimu_create() {
    CharacterList *character = character_get_free_cell();

    character->hp = 100;
    character->x = player_x;
    character->y = player_y;
    character->character_type = character_reimu;
    character->radius = 10;

    character->args[CMA(reimu, time_point_for_movement_x)] = 0;
    character->args[CMA(reimu, time_point_for_movement_y)] = 0;

    character->args[CMA(reimu, last_horizontal)] = 0;
    character->args[CMA(reimu, movement_animation)] = 0;

    character->args[CMA(reimu, step_of_movement)] = 0;

    character->args[CMA(reimu, move_percent)] = 0;
    character->args[CMA(reimu, move_begin_x)] = 0;
    character->args[CMA(reimu, move_begin_y)] = 0;

    return character;
}
@}
time_point_for_movement_to_x - может или нет персонаж переместиться по координате x,
  если этот параметр равен 0, то может. Этот параметр
  уменьшается функцией characters_update_all_time_points,
  и увеличивается функцией перемещения по координате x
time_point_for_movement_to_y - аналогично time_point_for_movement_to_x
step_of_movement - специальный параметр, который показывает какое действие совершается.
    Необходимо обнулять в конструкторе.

FIXME: last_horizontal, movement_animation не используются у рейму и марисы, потому что
  анимация для них не написана. Если они не потребуются, то использовать по другому.
  (Внизу есть код их инкрементации, не забыть удалить и его, если не используются)

@d Character public prototypes
@{CharacterList *character_reimu_create();
@}

@d Character public structs @{
enum {
    CMA(reimu, time_point_for_movement_x) = 0,
    CMA(reimu, time_point_for_movement_y),
    CMA(reimu, last_horizontal),
    CMA(reimu, movement_animation),
    CMA(reimu, step_of_movement),
    CMA(reimu, move_percent),
    CMA(reimu, move_begin_x),
    CMA(reimu, move_begin_y),
};
@}
move_percent, move_begin_x, move_begin_y - должны следовать подряд, так как это используется
  в character_move_to_point. Тоже самое и с time_point_for_movement_x, time_point_for_movement_y.

Мариса:
@d Character functions @{
CharacterList *character_marisa_create() {
    CharacterList *character = character_get_free_cell();

    character->hp = 100;
    character->x = player_x;
    character->y = player_y;
    character->character_type = character_marisa;
    character->radius = 10;

    character->args[CMA(marisa, time_point_for_movement_x)] = 0;
    character->args[CMA(marisa, time_point_for_movement_y)] = 0;

    character->args[CMA(marisa, last_horizontal)] = 0;
    character->args[CMA(marisa, movement_animation)] = 0;

    character->args[CMA(marisa, step_of_movement)] = 0;

    character->args[CMA(marisa, move_percent)] = 0;
    character->args[CMA(marisa, move_begin_x)] = 0;
    character->args[CMA(marisa, move_begin_y)] = 0;

    return character;
}
@}

@d Character public prototypes
@{CharacterList *character_marisa_create();
@}

@d Character public structs @{
enum {
    CMA(marisa, time_point_for_movement_x) = 0,
    CMA(marisa, time_point_for_movement_y),
    CMA(marisa, last_horizontal),
    CMA(marisa, movement_animation),
    CMA(marisa, step_of_movement),
    CMA(marisa, move_percent),
    CMA(marisa, move_begin_x),
    CMA(marisa, move_begin_y),
};
@}

Функции перемещения и восстановления очков перемещения.

Опишем вначале функцию перемещения:
@d Character functions @{
@<Different characters set weak time_point functions@>
@<character_set_weak_time_point functions@>

static void character_move_to(CharacterList *character,
    int args,
    int move_to) {
    int *const time_point_for_movement_to_x = &character->args[args];
    int *const time_point_for_movement_to_y = &character->args[args+1];

    if(*time_point_for_movement_to_x == 0) {
        if(move_to == character_move_to_left) {
            character_set_weak_time_point_x(character);
            character->x--;
        }
        else if(move_to == character_move_to_right) {
            character_set_weak_time_point_x(character);
            character->x++;
        }
    }

    if(*time_point_for_movement_to_y == 0) {
        if(move_to == character_move_to_up) {
            character_set_weak_time_point_y(character);
            character->y--;
        }
        else if(move_to == character_move_to_down) {
            character_set_weak_time_point_y(character);
            character->y++;
        }
    }
}
@}
В этой функции используются функции character_set_weak_time_point_x и
  character_set_weak_time_point_y. Они определяют тип персонажа character и
  вызывают специализированию функцию для каждого типа персонажа. Она устанавливает
  значение для time_point_for_movement_to_x и time_point_for_movement_to_y
  после того как было сделано перемещение.
Аргумент функции args содержит номер начиная с которого
  отсчитываются параметры time_point_for_movement_to_x/y в args.

Как видно, ход по x или y возможен только если соответствующий time_point равен нулю.

Направления в которые может перемещаться персонаж:
@d Character private structs @{
enum {
    character_move_to_left, character_move_to_right, character_move_to_up, character_move_to_down
};
@}

@d Character private prototypes @{
static void character_move_to(CharacterList *character, int args, int move_to);
@}



Опишем character_set_weak_time_point_x и character_set_weak_time_point_y:
@d character_set_weak_time_point functions @{
static void character_set_weak_time_point_x(CharacterList *character) {
    switch(character->character_type) {
        case character_reimu:
            character_reimu_set_weak_time_point_x(character);
            break;
        case character_marisa:
            character_marisa_set_weak_time_point_x(character);
            break;
        @<character_set_weak_time_point_x other characters@>
        default:
            fprintf(stderr, "\nUnknown character\n");
            exit(1);
    }
}

static void character_set_weak_time_point_y(CharacterList *character) {
    switch(character->character_type) {
        case character_reimu:
            character_reimu_set_weak_time_point_y(character);
            break;
        case character_marisa:
            character_marisa_set_weak_time_point_y(character);
            break;
        @<character_set_weak_time_point_y other characters@>
        default:
            fprintf(stderr, "\nUnknown character\n");
            exit(1);
    }
}
@}

Конкретные реализации функций обновления time_point:
@d Different characters set weak time_point functions @{
static void character_reimu_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(reimu, time_point_for_movement_x)] = 5;
}

static void character_reimu_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(reimu, time_point_for_movement_y)] = 5;
}

static void character_marisa_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(marisa, time_point_for_movement_x)] = 10;
}

static void character_marisa_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(marisa, time_point_for_movement_y)] = 10;
}
@}



Функция которая восстанавливает время до следующего хода
у всех персонажей в игре:
@d Character functions @{
@<Update time point for different characters@>

void characters_update_all_time_points(void) {
    CharacterList *character;

    for(character = characters; character != NULL; character = character->next)
        switch(character->character_type) {
            case character_reimu:
                character_reimu_update_time_points(character);
                break;
            case character_marisa:
                character_marisa_update_time_points(character);
                break;
            @<characters_update_all_time_points other characters@>
            default:
                fprintf(stderr, "\nUnknown character\n");
                exit(1);
        }
}
@}
characters_update_all_time_points нужно вызывать в конце
каждого опроса перемещений ВСЕХ персонажей. Она восстанавливает очки перемещения у
всех персонажей, те после определённого количества вызовов этой функции,
персонажы смогут сделать один ход.

@d Character public prototypes
@{void characters_update_all_time_points(void);
@}

Реализация обновления времени до следующего хода у конкретного вида
персонажей:
@d Update time point for different characters @{
static void character_reimu_update_time_points(CharacterList *character) {
    if(character->args[CMA(reimu, time_point_for_movement_x)] > 0)
        character->args[CMA(reimu, time_point_for_movement_x)]--;

    if(character->args[CMA(reimu, time_point_for_movement_y)] > 0)
        character->args[CMA(reimu, time_point_for_movement_y)]--;

    character->args[CMA(reimu, movement_animation)]++;
}

static void character_marisa_update_time_points(CharacterList *character) {
    if(character->args[CMA(marisa, time_point_for_movement_x)] > 0)
        character->args[CMA(marisa, time_point_for_movement_x)]--;

    if(character->args[CMA(marisa, time_point_for_movement_y)] > 0)
        character->args[CMA(marisa, time_point_for_movement_y)]--;

    character->args[CMA(marisa, movement_animation)]++;
}
@}
Фаза анимации movement_animation тоже обновляется здесь.


Сделаем ход всеми компьютерными персонажами:
@d Character functions @{
@<Helper functions@>
@<AI functions for different characters@>

void characters_ai_control(void) {
    CharacterList *character;

    for(character = characters; character != NULL; character = character->next) {
        switch(character->character_type) {
            case character_reimu:
                character_reimu_ai_control(character);
                break;
            case character_marisa:
                character_marisa_ai_control(character);
                break;
            @<characters_ai_control other characters@>
            default:
                fprintf(stderr, "\nUnknown character\n");
                exit(1);
        }
    }

    character_pool_free_to_pool();
}
@}

@d Character public prototypes
@{void characters_ai_control(void);
@}

Мозги для конкретных персонажей:
@d AI functions for different characters @{
static void character_reimu_ai_control(CharacterList *character) {
    @<Reimu ai control@>
}

static void character_marisa_ai_control(CharacterList *character) {
    exit(1); // FIXME
}
@}


==============================================================

Вспомогательные функции.

character_move_to_point - движение к точке.
Каждый её вызов передвигает персонаж character ближе к точке (x,y)

@d Helper functions @{
static void character_move_to_point(CharacterList *character, int args1, int args2, int x, int y) {
    int *const move_percent = &character->args[args1];
    int *const move_begin_x = &character->args[args1+1];
    int *const move_begin_y = &character->args[args1+2];

    @<character_move_to_point params@>
    @<character_move_to_point is end of movement?@>
    @<character_move_to_point save start coordinate@>
    @<character_move_to_point calculate percent of movement@>
    @<character_move_to_point choose direction@>
}
@}
move_percent - процент пути который осталось пройти. В конце пути он равен 0.
Для того чтобы сбросить старое движение и начать новое, нужно присвоить move_percent 0.
move_begin_x, move_begin_y - начальные координаты движения.
args1 - указывает на move_percent, move_begin_x, move_begin_y
args2 - указывает на time_point_for_movement_to_x/y

Проверим достигли мы конечной точки или нет:
@d character_move_to_point is end of movement? @{
if(character->x == x && character->y == y) {
    *move_percent = 0;
    return;
}
@}
Мы не забыли установить процент движения move_percent в 0. Движения больше нет.


Если мы только начали движение, то нужно запомнить начальные координаты
движения:
@d character_move_to_point save start coordinate @{
if(*move_percent == 0) {
    *move_begin_x = character->x;
    *move_begin_y = character->y;
}
@}
Можно считать, что move_percent = 100.

Посчитаем какой процент расстояния осталось пройти. Для этого поделим расстояние
до конечной точки на длину всего маршрута:
@d character_move_to_point calculate percent of movement @{
{
    int dx, dy;
    float all, last;

    dx = *move_begin_x - x;
    dy = *move_begin_y - y;
    @<character_move_to_point find correction coef@>

    all = sqrt(dx*dx + dy*dy);

    dx = character->x - x;
    dy = character->y - y;
    @<character_move_to_point correction coef at this time@>

    last = sqrt(dx*dx + dy*dy);

    *move_percent = (int)((last/all) * 100.0);
}
@}
Поиски correction coef не относятся к этой задаче, зачем они написано ниже.
FIXME: возможно стоит перенести поиск процента оставшегося растояния в отдельную функцию,
а атрибут move_percent убрать. (+) освободим память, (-) чаще будем пересчитывать move_percent.


Найдем коэффициент с которого мы будем сверять отклонение от маршрута:
@d character_move_to_point find correction coef @{
if(dy == 0)
    correction_coef = 100.0;
else
    correction_coef = fabs((float)dx/(float)dy);
@}

@d character_move_to_point params @{
float correction_coef;
@}


Найдем значение этого же коффициента, но не для всего маршрута, а для
оставшейся части:
@d character_move_to_point correction coef at this time @{
if(dy == 0)
    now_coef = 100.0;
else
    now_coef = fabs((float)dx/(float)dy);
@}

@d character_move_to_point params @{
float now_coef;
@}


Выберем направление движения:
@d character_move_to_point choose direction @{
if(now_coef < correction_coef)
    fy = 1;
else if(now_coef > correction_coef)
    fx = 1;
else {
    fx = 1;
    fy = 1;
}

if(fx == 1 && character->x != x) {
    if(character->x > x)
        character_move_to(character, args2, character_move_to_left);
    else
        character_move_to(character, args2, character_move_to_right);
}

if(fy == 1 && character->y != y) {
    if(character->y > y)
        character_move_to(character, args2, character_move_to_up);
    else
        character_move_to(character, args2, character_move_to_down);
}
@}

@d character_move_to_point params @{
int fx = 0, fy = 0;
@}



Далее нам понадобится функция для перемещения персонажа под определённым
углом, на определённую дистанцию:
@d Helper functions @{
static void character_move_to_angle_and_radius(CharacterList *character,
    int args1, int args2, float angle, float radius) {
    int *const move_percent = &character->args[args1];
    int *const move_begin_x = &character->args[args1+1];
    int *const move_begin_y = &character->args[args1+2];
    const double deg2rad = M_PI/180.0;
    int move_x, move_y;

    if(move_percent == 0) {
        *move_begin_x = character->x;
        *move_begin_y = character->y;
    }

    move_x = *move_begin_x + (int)(radius*cos(angle*deg2rad));
    move_y = *move_begin_y + (int)(radius*sin(angle*deg2rad));

    character_move_to_point(character, args1, args2, move_x, move_y);
}
@}
args1 - указывает на move_percent, move_begin_x, move_begin_y
args2 - указывает на time_point_for_movement_to_x/y

===========================================================


Опишем поведение боссов.
Пусть оно пока храниться здесь, позже перенесу.

Босс движется из точки в точку. Достигает её. Мы изменяем step_of_movement,
чтобы знать какой шаг делать потом.

@d Character private structs @{
typedef struct {
    int x, y;
} Point;
@}

@d Reimu ai control @{
int *const step_of_movement = &character->args[CMA(reimu, step_of_movement)];
int *const move_percent = &character->args[CMA(reimu, move_percent)];
Point p[] = {{100, 100}, {200, 10}, {10, 200}, {200, 200}, {10, 10}};

@<character_reimu_ai_control is character dead?@>

if(*step_of_movement == 5)
    *step_of_movement = 0;

character_move_to_point(character, CMA(reimu, move_percent),
    CMA(reimu, time_point_for_movement_x), p[*step_of_movement].x, p[*step_of_movement].y);

if(*move_percent == 0) {
    (*step_of_movement)++;
}
@}

Если у персонажа hp <= 0:
@d character_reimu_ai_control is character dead? @{
if(character->hp <= 0) {
    character_free(character);
    return;
}
@}

Перемещаемся между точками.


===========================================================

Функция которая рисует всех персонажей, которые не спят.
Стоит рисовать её до того как нарисовать рамку, чтобы рамка перекрыла
не полностью вылезших персонажей.


@d Character functions @{
@<Draw functions for different characters@>

void characters_draw(void) {
    CharacterList *character;

    for(character = characters; character != NULL; character = character->next)
        switch(character->character_type) {
            case character_reimu:
                character_reimu_draw(character);
                break;
            case character_marisa:
                character_marisa_draw(character);
                break;
            @<characters_draw other characters@>
            default:
                fprintf(stderr, "\nUnknown character\n");
                exit(1);
        }
}
@}

@d Character public prototypes
@{void characters_draw(void);
@}

Конкретные функции рисования для различных персонажей:
FIXME: нет анимации, смотреть у blue_fairy
@d Draw functions for different characters @{
static void character_reimu_draw(CharacterList *character) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/aya.png");

    image_draw_center(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        0, 0.1);
}

static void character_marisa_draw(CharacterList *character) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/marisa.png");

    image_draw_center(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        0, 0.1);
}
@}


FIXME: написаное ниже актуально лишь частично, так как этот механизм не позволяет реализовывать
   просто телохранителей персонажей(точнее это возможно, но нам придётся аллоцировать ячейки и
   для них, а их много). Поэтому повышение сложность и замена стека аллокатором оправдано.

TODO: Есть одна мысль.
Уберем механизм стека и функцию character_create вместе с character_reimu, character_marisa.

Пусть у нас будет два этажа, напишем код создания монстров для них:

void level01(void) {
    enum {
        lvl01_main_hero, lvl01_fly_monster_1, lvl01_fly_monster_2, ...,
        lvl01_midboss, lvl01_fly_monster_10, ..., lvl01_boss
    };

    // character_main_hero_create(lvl01_main_hero);
    character_fly_monster_create(lvl01_fly_monster_1);
    character_fly_monster_create(lvl01_fly_monster_2);
    ...
    character_night_bug_create(lvl01_midboss);
    character_fly_monster_create(lvl01_fly_monster_10);
    ...
    character_sparow_create(lvl01_boss);

    character_list_pos = lvl01_boss + 1;
}

Создание главного героя закомментировано поскольку к этому моменту главный герой уже создан.

void level02(void) {

    enum {
        lvl02_main_hero, lvl02_yellow_fly_monster, lvl02_green_fly_monster, ...,
        lvl02_midboss, lvl02_pink_fly_monster, ..., lvl02_boss
    };

    character_yellow_fly_monster_create(lvl02_yellow_fly_monster);
    ...
    character_list_pos = lvl02_boss + 1;
}

В конце мы задаем character_list_pos чтобы не проходить по всему массиву.

Этот механизм прост и даёт хорошую гибкость. Для пуль он малопригоден, но они,
в отличии от персонажей, удаляются.
С помощью такого механизма мы можем не бороться с дескрипторами и переносить в
следующий этаж только нужных персонажей.

======================================================================

Начнем добавлять персонажей:

Лунные феи.

Синие феи.

Нарытые факты:
 - феи вылетают кучей (на easy в куче 3 феи).
 - у этой кучи есть вертикальная линия на экране.
   После того как феи доллетают до конца, они начинают лететь назад зеркально относительно этой
   линии(рис. blue_fairy_track). Угол отклонения зависит от расстояния до этой линии(чем ближе тем угол больше).
 - к концу пути они замедляют движение, при полёте назад опять ускоряются.
 - в конце выстраиваются в одну горизонтальную линию.

Надо изменить рисовку этой феи, так как в IN она крыльями почти не машет, а планирует на них.

"Умный" алгоритм не понятен(странный разброс углов), поэтому нужно будет задавать 3 точки:
 - откуда летит(точка появления)
 - куда летит прямо
 - куда летит обратно

Добавим в список:
@d Character types
@{character_blue_moon_fairy,
@}

Функция создания персонажа:
@d Character functions @{
CharacterList *character_blue_moon_fairy_create(int begin_x, int begin_y,
    int to_x, int to_y,
    int end_x, int end_y) {
    CharacterList *character = character_get_free_cell();

    character->x = begin_x;
    character->y = begin_y;
    character->hp = 100;
    character->character_type = character_blue_moon_fairy;
    character->radius = 10;

    character->args[CMA(blue_moon_fairy, time_point_for_movement_x)] = 0;
    character->args[CMA(blue_moon_fairy, time_point_for_movement_y)] = 0;

    character->args[CMA(blue_moon_fairy, move_x)] = to_x;
    character->args[CMA(blue_moon_fairy, move_y)] = to_y;

    character->args[CMA(blue_moon_fairy, end_x)] = end_x;
    character->args[CMA(blue_moon_fairy, end_y)] = end_y;

    character->args[CMA(blue_moon_fairy, last_horizontal)] = 0;
    character->args[CMA(blue_moon_fairy, movement_animation)] = 0;

    character->args[CMA(blue_moon_fairy, speed)] = 0;

    character->args[CMA(blue_moon_fairy, step_of_movement)] = 0;

    character->args[CMA(blue_moon_fairy, move_percent)] = 0;
    character->args[CMA(blue_moon_fairy, move_begin_x)] = 0;
    character->args[CMA(blue_moon_fairy, move_begin_y)] = 0;

    character->args[CMA(blue_moon_fairy, time)] = 0;

    return character;
}
@}
radius - радиус хитбокса;
speed - скорость(описана ниже).
end_x, end_y - определены для синей феи, в эту точку она будет лететь назад
speed - 0 - минимальная скорость; 100 - максимальная
move_x, move_y - требуются, когда нужно где-то сохранить точку куда двигается персонаж.
  Используются в ai, а move_x и в функции вырисовки.
Иногда нужно ждать некоторое время, таймер можно хранить в time
last_horizontal - направление движения по горизонтали(-1 влево, 0 нет движения, 1 вправо);
    при прошлой вырисовке персонажа(для продолжения     анимации); обнулять в конструкторе.
movement_animation - фаза анимации; вначале равна 0, инкрементируется там же где уменьшается
    time points; обнуляется в функции вырисовки; необходимо обнулять в конструкторе.

Я пытался сделать анимацию как в player, те была ещё переменная horizontal, которая была
    или 0, или -1, или 1. Но из-за того, что функция рисования линии не определяла движение
    по диагонали, персонаж постоянно дёргался(смотрел то вперёд, то в сторону). Пришлось
    делать с move_x, но это не плохо(кажется).

Используются три точки как и описано выше.

@d Character public prototypes
@{CharacterList *character_blue_moon_fairy_create(int begin_x, int begin_y, int to_x, int to_y, int end_x, int end_y);
@}

@d Character public structs @{
enum {
    CMA(blue_moon_fairy, time_point_for_movement_x) = 0,
    CMA(blue_moon_fairy, time_point_for_movement_y),
    CMA(blue_moon_fairy, move_x),
    CMA(blue_moon_fairy, move_y),
    CMA(blue_moon_fairy, end_x),
    CMA(blue_moon_fairy, end_y),
    CMA(blue_moon_fairy, last_horizontal),
    CMA(blue_moon_fairy, movement_animation),
    CMA(blue_moon_fairy, speed),
    CMA(blue_moon_fairy, step_of_movement),
    CMA(blue_moon_fairy, move_percent),
    CMA(blue_moon_fairy, move_begin_x),
    CMA(blue_moon_fairy, move_begin_y),
    CMA(blue_moon_fairy, time)
};
@}
move_percent, move_begin_x, move_begin_y - должны следовать подряд, так как это используется
  в character_move_to_point. Тоже самое и с time_point_for_movement_x, time_point_for_movement_y.
CMA - макрос описанный выше, создаёт имя параметра через конкатенацию своих параметров.

Функции установки time points после совершения перемещения:
@d character_set_weak_time_point_x other characters
@{case character_blue_moon_fairy:
    character_blue_moon_fairy_set_weak_time_point_x(character);
    break;
@}

@d character_set_weak_time_point_y other characters
@{case character_blue_moon_fairy:
    character_blue_moon_fairy_set_weak_time_point_y(character);
    break;
@}

Добавление time points с возможностью изменять скорость:
@d Different characters set weak time_point functions @{
static void character_blue_moon_fairy_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(blue_moon_fairy, time_point_for_movement_x)] = 100 - (character->args[CMA(blue_moon_fairy, speed)] / 1.1);
}

static void character_blue_moon_fairy_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(blue_moon_fairy, time_point_for_movement_y)] = 100 - (character->args[CMA(blue_moon_fairy, speed)] / 1.1);
}
@}

Функции обновления time points:
@d characters_update_all_time_points other characters
@{case character_blue_moon_fairy:
    character_blue_moon_fairy_update_time_points(character);
    break;
@}

@d Update time point for different characters @{
static void character_blue_moon_fairy_update_time_points(CharacterList *character) {
    if(character->args[CMA(blue_moon_fairy, time_point_for_movement_x)] > 0)
        character->args[CMA(blue_moon_fairy, time_point_for_movement_x)]--;

    if(character->args[CMA(blue_moon_fairy, time_point_for_movement_y)] > 0)
        character->args[CMA(blue_moon_fairy, time_point_for_movement_y)]--;

    character->args[CMA(blue_moon_fairy, movement_animation)]++;
}
@}
Меняем и movement_animation

AI феи:
@d characters_ai_control other characters
@{case character_blue_moon_fairy:
    character_blue_moon_fairy_ai_control(character);
    break;
@}

@d AI functions for different characters @{
static void character_blue_moon_fairy_ai_control(CharacterList *character) {
    int *const move_x = &character->args[CMA(blue_moon_fairy, move_x)];
    int *const move_y = &character->args[CMA(blue_moon_fairy, move_y)];
    int *const end_x = &character->args[CMA(blue_moon_fairy, end_x)];
    int *const end_y = &character->args[CMA(blue_moon_fairy, end_y)];
    int *const speed = &character->args[CMA(blue_moon_fairy, speed)];
    int *const step_of_movement = &character->args[CMA(blue_moon_fairy, step_of_movement)];
    int *const move_percent = &character->args[CMA(blue_moon_fairy, move_percent)];
    int *const time = &character->args[CMA(blue_moon_fairy, time)];

    @<character_blue_moon_fairy_ai_control is character dead?@>
    @<character_blue_moon_fairy_ai_control move to down@>
    @<character_blue_moon_fairy_ai_control wait@>
    @<character_blue_moon_fairy_ai_control go away@>
    @<character_blue_moon_fairy_ai_control move to up@>
    @<character_blue_moon_fairy_ai_control remove@>
}
@}

Если у персонажа hp <= 0:
@d character_blue_moon_fairy_ai_control is character dead? @{
if(character->hp <= 0) {
    character_free(character);
    return;
}
@}

Перемещаемся вперёд:
@d character_blue_moon_fairy_ai_control move to down
@{if(*step_of_movement == 0) {
    character_move_to_point(character, CMA(blue_moon_fairy, move_percent),
        CMA(blue_moon_fairy, time_point_for_movement_x), *move_x, *move_y);

    *speed = 60 + (log(*move_percent+1) / log(101)) * 100.0;
    if(*speed > 100)
        *speed = 100;

    if(*move_percent == 0) {
        *time = 6000;
        *step_of_movement = 1;
    }
}
@}

Ждем 3 секунды(character->time выше):
@d character_blue_moon_fairy_ai_control wait
@{if(*step_of_movement == 1) {
    (*time)--;

    if(*time == 0)
        *step_of_movement = 2;
}
@}

Летим к конечной точке:
@d character_blue_moon_fairy_ai_control go away
@{if(*step_of_movement == 2) {
    *move_x = *end_x;
    *move_y = *end_y;
    *step_of_movement = 3;
}
@}

@d character_blue_moon_fairy_ai_control move to up
@{if(*step_of_movement == 3) {
    character_move_to_point(character, CMA(blue_moon_fairy, move_percent),
        CMA(blue_moon_fairy, time_point_for_movement_x), *move_x, *move_y);

    *speed = 130 - pow(101, *move_percent/100.0) + 1;
    if(*speed > 100)
        *speed = 100;

    if(*move_percent == 0)
        *step_of_movement = 4;
}
@}

@d character_blue_moon_fairy_ai_control remove
@{if(*step_of_movement == 4) {
    if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
        character->y < -25 || character->y > GAME_FIELD_H + 25) {
        character_free(character);
    }
}
@}
Фея после достижения конечной точки исчезает только если она за пределами экрана.

Рисуем персонажа:
@d characters_draw other characters
@{case character_blue_moon_fairy:
    character_blue_moon_fairy_draw(character);
    break;
@}

@d Draw functions for different characters @{
static void character_blue_moon_fairy_draw(CharacterList *character) {
    int *const move_x = &character->args[CMA(blue_moon_fairy, move_x)];
    int *const last_horizontal = &character->args[CMA(blue_moon_fairy, last_horizontal)];
    int *const movement_animation = &character->args[CMA(blue_moon_fairy, movement_animation)];

    static int id = -1;

    if(id == -1)
        id = image_load("images/blue_fairy.png");

    if(character->x == *move_x) {
        if(*movement_animation > 200)
            *movement_animation = 0;

        if(*movement_animation < 50)
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                2, 13, 2+120, 13+108,
                0, 0.4);
        else if(*movement_animation < 100)
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                120, 13, 120+120, 13+108,
                0, 0.4);
        else if(*movement_animation < 150)
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                240, 12, 240+120, 12+109,
                0, 0.4);
        else
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                365, 12, 365+122, 12+109,
                0, 0.4);
    } else if(character->x < *move_x) {
        @<character_blue_moon_fairy_draw left@>
    } else if(character->x > *move_x) {
        @<character_blue_moon_fairy_draw right@>
    }
}
@}

@d character_blue_moon_fairy_draw left
@{if(*last_horizontal != 1)
    *movement_animation = 0;

*last_horizontal = 1;

if(*movement_animation > 200)
    *movement_animation = 0;

if(*movement_animation < 50)
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        8, 123, 8+105, 123+123,
        0, 0.4);
else if(*movement_animation < 100)
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        127, 123, 127+105, 123+123,
        0, 0.4);
else if(*movement_animation < 150)
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        242, 123, 242+105, 123+123,
        0, 0.4);
else
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        365, 123, 365+105, 123+123,
        0, 0.4);
@}

@d character_blue_moon_fairy_draw right
@{if(*last_horizontal != -1)
    *movement_animation = 0;

*last_horizontal = -1;

if(*movement_animation > 200)
    *movement_animation = 0;

if(*movement_animation < 50)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        8, 123, 8+105, 123+123,
        0, 0.4);
else if(*movement_animation < 100)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        127, 123, 127+105, 123+123,
        0, 0.4);
else if(*movement_animation < 150)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        242, 123, 242+105, 123+123,
        0, 0.4);
else
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        365, 123, 365+105, 123+123,
        0, 0.4);
@}

Повреждение от пуль:
@d damage_calculate other enemy characters
@{case character_blue_moon_fairy:
    if(bullet->bullet_type == bullet_reimu_first)
        character->hp -= 1000;
    break;
@}



Феи с кроличьими ушами.


@d Character types
@{character_blue_moon_bunny_fairy,
@}

@d Character functions @{
CharacterList *character_blue_moon_bunny_fairy_create(int begin_x, int begin_y,
    int to_x, int to_y,
    int end_x, int end_y) {
    CharacterList *character = character_get_free_cell();

    character->x = begin_x;
    character->y = begin_y;
    character->hp = 100;
    character->character_type = character_blue_moon_bunny_fairy;
    character->radius = 10;

    character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_x)] = 0;
    character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_y)] = 0;

    character->args[CMA(blue_moon_bunny_fairy, move_x)] = to_x;
    character->args[CMA(blue_moon_bunny_fairy, move_y)] = to_y;

    character->args[CMA(blue_moon_bunny_fairy, end_x)] = end_x;
    character->args[CMA(blue_moon_bunny_fairy, end_y)] = end_y;

    character->args[CMA(blue_moon_bunny_fairy, last_horizontal)] = 0;
    character->args[CMA(blue_moon_bunny_fairy, movement_animation)] = 0;

    character->args[CMA(blue_moon_bunny_fairy, speed)] = 0;

    character->args[CMA(blue_moon_bunny_fairy, step_of_movement)] = 0;

    character->args[CMA(blue_moon_bunny_fairy, move_percent)] = 0;
    character->args[CMA(blue_moon_bunny_fairy, move_begin_x)] = 0;
    character->args[CMA(blue_moon_bunny_fairy, move_begin_y)] = 0;

    character->args[CMA(blue_moon_bunny_fairy, time)] = 0;

    character->args[CMA(blue_moon_bunny_fairy, child)] = (intptr_t)NULL; //child -- yellow fire

    return character;
}
@}
child - ссылка на одного из детей, у каждого ребёнка(кроме последнего) есть ссылка на другого.
Описание остальных параметров аналогичны blue_moon_fairy

@d Character public prototypes
@{CharacterList *character_blue_moon_bunny_fairy_create(int begin_x, int begin_y, int to_x, int to_y, int end_x, int end_y);
@}

@d Character public structs @{
enum {
    CMA(blue_moon_bunny_fairy, time_point_for_movement_x) = 0,
    CMA(blue_moon_bunny_fairy, time_point_for_movement_y),
    CMA(blue_moon_bunny_fairy, move_x),
    CMA(blue_moon_bunny_fairy, move_y),
    CMA(blue_moon_bunny_fairy, end_x),
    CMA(blue_moon_bunny_fairy, end_y),
    CMA(blue_moon_bunny_fairy, last_horizontal),
    CMA(blue_moon_bunny_fairy, movement_animation),
    CMA(blue_moon_bunny_fairy, speed),
    CMA(blue_moon_bunny_fairy, step_of_movement),
    CMA(blue_moon_bunny_fairy, move_percent),
    CMA(blue_moon_bunny_fairy, move_begin_x),
    CMA(blue_moon_bunny_fairy, move_begin_y),
    CMA(blue_moon_bunny_fairy, time),
    CMA(blue_moon_bunny_fairy, child)
};
@}

@d character_set_weak_time_point_x other characters
@{case character_blue_moon_bunny_fairy:
    character_blue_moon_bunny_fairy_set_weak_time_point_x(character);
    break;
@}

@d character_set_weak_time_point_y other characters
@{case character_blue_moon_bunny_fairy:
    character_blue_moon_bunny_fairy_set_weak_time_point_y(character);
    break;
@}

@d Different characters set weak time_point functions @{
static void character_blue_moon_bunny_fairy_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_x)] = 10 - (character->args[CMA(blue_moon_bunny_fairy, speed)] / 10.1);
}

static void character_blue_moon_bunny_fairy_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_y)] = 10 - (character->args[CMA(blue_moon_bunny_fairy, speed)] / 10.1);
}
@}

@d characters_update_all_time_points other characters
@{case character_blue_moon_bunny_fairy:
    character_blue_moon_bunny_fairy_update_time_points(character);
    break;
@}

@d Update time point for different characters @{
static void character_blue_moon_bunny_fairy_update_time_points(CharacterList *character) {
    if(character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_x)] > 0)
        character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_x)]--;

    if(character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_y)] > 0)
        character->args[CMA(blue_moon_bunny_fairy, time_point_for_movement_y)]--;

    character->args[CMA(blue_moon_bunny_fairy, movement_animation)]++;
}
@}

@d characters_ai_control other characters
@{case character_blue_moon_bunny_fairy:
    character_blue_moon_bunny_fairy_ai_control(character);
    break;
@}

@d AI functions for different characters @{
static void character_blue_moon_bunny_fairy_ai_control(CharacterList *character) {
    int *const move_x = &character->args[CMA(blue_moon_bunny_fairy, move_x)];
    int *const move_y = &character->args[CMA(blue_moon_bunny_fairy, move_y)];
    int *const end_x = &character->args[CMA(blue_moon_bunny_fairy, end_x)];
    int *const end_y = &character->args[CMA(blue_moon_bunny_fairy, end_y)];
    int *const speed = &character->args[CMA(blue_moon_bunny_fairy, speed)];
    int *const step_of_movement = &character->args[CMA(blue_moon_bunny_fairy, step_of_movement)];
    int *const move_percent = &character->args[CMA(blue_moon_bunny_fairy, move_percent)];
    int *const time = &character->args[CMA(blue_moon_bunny_fairy, time)];

    @<character_blue_moon_bunny_fairy_ai_control is character dead?@>
    @<character_blue_moon_bunny_fairy_ai_control move to down@>
    @<character_blue_moon_bunny_fairy_ai_control wait@>
    @<character_blue_moon_bunny_fairy_ai_control go away@>
    @<character_blue_moon_bunny_fairy_ai_control move to up@>
    @<character_blue_moon_bunny_fairy_ai_control remove@>
}
@}

Если у персонажа hp <= 0:
@d character_blue_moon_bunny_fairy_ai_control is character dead? @{
if(character->hp <= 0) {
    character_remove_hp_all_childs((CharacterList*)(character->args[CMA(blue_moon_bunny_fairy, child)]),
        CMA(yellow_fire, next_child));
    character_free(character);
    return;
}
@}
При уничтожении феи с заячьими ушами удаляются и дочернии ему жёлтые огоньки.

@d Helper functions @{
static void character_remove_hp_all_childs(CharacterList *first_child, int next_child_arg) {
    CharacterList *p = first_child;

    while(p != NULL) {
        p->hp = 0;
        p = (CharacterList*)(p->args[next_child_arg]);
    }
}
@}
next_child_arg - номер элемента args у child который указывает на следующий child.


Перемещаемся вперёд, когда достигнем точки назначения, то
создаём огоньки и настраиваем таймер:
@d character_blue_moon_bunny_fairy_ai_control move to down
@{if(*step_of_movement == 0) {
    *speed = 50;
    character_move_to_point(character, CMA(blue_moon_bunny_fairy, move_percent),
        CMA(blue_moon_bunny_fairy, time_point_for_movement_x), *move_x, *move_y);

    if(*move_percent == 0) {
        CharacterList **const child = (CharacterList**)&(character->args[CMA(blue_moon_bunny_fairy, child)]);
        CharacterList *p;

        p = character_yellow_fire_create(character, 0, 0, NULL);
        p = character_yellow_fire_create(character, 180, 0, p);
        p = character_yellow_fire_create(character, 90, 0, p);
        p = character_yellow_fire_create(character, 270, 0, p);

        *child = p;

        *time = 12000;
        *step_of_movement = 1;
    }
}
@}
Родитель ссылается только на одного ребёнка, но каждый ребёнок(кроме последнего) ссылается
  на другого. Таким образом родитель может обойти их всех.

Ждем ~6 секунд(character->time выше):
@d character_blue_moon_bunny_fairy_ai_control wait
@{if(*step_of_movement == 1) {
    (*time)--;

    if(*time == 0)
        *step_of_movement = 2;
}
@}

Летим к конечной точке:
@d character_blue_moon_bunny_fairy_ai_control go away
@{if(*step_of_movement == 2) {
    *move_x = *end_x;
    *move_y = *end_y;
    *step_of_movement = 3;
}
@}

@d character_blue_moon_bunny_fairy_ai_control move to up
@{if(*step_of_movement == 3) {
    *speed = 10;
    character_move_to_point(character, CMA(blue_moon_bunny_fairy, move_percent),
        CMA(blue_moon_bunny_fairy, time_point_for_movement_x), *move_x, *move_y);

    if(*move_percent == 0)
        *step_of_movement = 4;
}
@}

@d character_blue_moon_bunny_fairy_ai_control remove
@{if(*step_of_movement == 4) {
    if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
        character->y < -25 || character->y > GAME_FIELD_H + 25) {
        character_free(character);
    }
}
@}
Фея после достижения конечной точки исчезает только если она за пределами экрана.


Рисуем персонажа:
@d characters_draw other characters
@{case character_blue_moon_bunny_fairy:
    character_blue_moon_bunny_fairy_draw(character);
    break;
@}

@d Draw functions for different characters @{
static void character_blue_moon_bunny_fairy_draw(CharacterList *character) {
    int *const move_x = &character->args[CMA(blue_moon_bunny_fairy, move_x)];
    int *const last_horizontal = &character->args[CMA(blue_moon_bunny_fairy, last_horizontal)];
    int *const movement_animation = &character->args[CMA(blue_moon_bunny_fairy, movement_animation)];

    static int id = -1;

    if(id == -1)
        id = image_load("images/blue_fairy.png");

    if(character->x == *move_x) {
        if(*movement_animation > 200)
            *movement_animation = 0;

        if(*movement_animation < 50)
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                2, 13, 2+120, 13+108,
                0, 0.4);
        else if(*movement_animation < 100)
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                120, 13, 120+120, 13+108,
                0, 0.4);
        else if(*movement_animation < 150)
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                240, 12, 240+120, 12+109,
                0, 0.4);
        else
            image_draw_center_t(id,
                GAME_FIELD_X + character->x,
                GAME_FIELD_Y + character->y,
                365, 12, 365+122, 12+109,
                0, 0.4);
    } else if(character->x < *move_x) {
        @<character_blue_moon_bunny_fairy_draw left@>
    } else if(character->x > *move_x) {
        @<character_blue_moon_bunny_fairy_draw right@>
    }
}
@}

@d character_blue_moon_bunny_fairy_draw left
@{if(*last_horizontal != 1)
    *movement_animation = 0;

*last_horizontal = 1;

if(*movement_animation > 200)
    *movement_animation = 0;

if(*movement_animation < 50)
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        8, 123, 8+105, 123+123,
        0, 0.4);
else if(*movement_animation < 100)
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        127, 123, 127+105, 123+123,
        0, 0.4);
else if(*movement_animation < 150)
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        242, 123, 242+105, 123+123,
        0, 0.4);
else
    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        365, 123, 365+105, 123+123,
        0, 0.4);
@}

@d character_blue_moon_bunny_fairy_draw right
@{if(*last_horizontal != -1)
    *movement_animation = 0;

*last_horizontal = -1;

if(*movement_animation > 200)
    *movement_animation = 0;

if(*movement_animation < 50)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        8, 123, 8+105, 123+123,
        0, 0.4);
else if(*movement_animation < 100)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        127, 123, 127+105, 123+123,
        0, 0.4);
else if(*movement_animation < 150)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        242, 123, 242+105, 123+123,
        0, 0.4);
else
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        365, 123, 365+105, 123+123,
        0, 0.4);
@}

Повреждение от пуль:
@d damage_calculate other enemy characters
@{case character_blue_moon_bunny_fairy:
    if(bullet->bullet_type == bullet_reimu_first)
        character->hp -= 1000;
    break;
@}



Жёлтый огонёк.

Вылетает из феи с кроличьими ушами и начинает кружить вокруг неё(на easy 2 или 4 штуки).
Заменяется пинктограммами для ёкаев.
Кружит против часовой стрелки.
Когда по 4 стреляют.

Вокруг wriggl'а тоже что-то летает, но пусть это будет другой монстр(у него траектория сложнее).

Следовательно:
 - при создании будет параметр: стреляет или нет
 - параметр угла под которым он вылетает

@d Character types
@{character_yellow_fire,
@}

@d Character functions @{
CharacterList *character_yellow_fire_create(CharacterList *parent,
    int angle, int is_fire, CharacterList *sister) {
    CharacterList *character = character_get_free_cell();

    character->x = parent->x;
    character->y = parent->y;
    character->hp = 100;
    character->character_type = character_yellow_fire;
    character->radius = 10;

    character->args[CMA(yellow_fire, time_point_for_movement_x)] = 0;
    character->args[CMA(yellow_fire, time_point_for_movement_y)] = 0;

    character->args[CMA(yellow_fire, angle)] = angle;

    character->args[CMA(yellow_fire, is_fire)] = is_fire;

    character->args[CMA(yellow_fire, movement_animation)] = 0;

    character->args[CMA(yellow_fire, step_of_movement)] = 0;

    character->args[CMA(yellow_fire, parent)] = (intptr_t)parent;

    character->args[CMA(yellow_fire, move_percent)] = 0;
    character->args[CMA(yellow_fire, move_begin_x)] = 0;
    character->args[CMA(yellow_fire, move_begin_y)] = 0;

    character->args[CMA(yellow_fire, radius)] = 0;

    character->args[CMA(yellow_fire, next_child)] = (intptr_t)sister; //next child yellow fire

    return character;
}
@}
sister - ссылка на другой огонёк того же родителя parent.
  По этой ссылке родитель сможет обойти всех своих детей ссылаясь только на одного.

@d Character public prototypes
@{CharacterList *character_yellow_fire_create(CharacterList *parent, int angle, int is_fire, CharacterList *sister);
@}


@d Character public structs @{
enum {
    CMA(yellow_fire, time_point_for_movement_x) = 0,
    CMA(yellow_fire, time_point_for_movement_y),
    CMA(yellow_fire, angle),
    CMA(yellow_fire, is_fire),
    CMA(yellow_fire, movement_animation),
    CMA(yellow_fire, step_of_movement),
    CMA(yellow_fire, parent),
    CMA(yellow_fire, move_percent),
    CMA(yellow_fire, move_begin_x),
    CMA(yellow_fire, move_begin_y),
    CMA(yellow_fire, radius),
    CMA(yellow_fire, next_child)
};
@}

@d character_set_weak_time_point_x other characters
@{case character_yellow_fire:
    character_yellow_fire_set_weak_time_point_x(character);
    break;
@}

@d character_set_weak_time_point_y other characters
@{case character_yellow_fire:
    character_yellow_fire_set_weak_time_point_y(character);
    break;
@}

@d Different characters set weak time_point functions @{
static void character_yellow_fire_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(yellow_fire, time_point_for_movement_x)] = 30;
}

static void character_yellow_fire_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(yellow_fire, time_point_for_movement_y)] = 30;
}
@}

@d characters_update_all_time_points other characters
@{case character_yellow_fire:
    character_yellow_fire_update_time_points(character);
    break;
@}

@d Update time point for different characters @{
static void character_yellow_fire_update_time_points(CharacterList *character) {
    if(character->args[CMA(yellow_fire, time_point_for_movement_x)] > 0)
        character->args[CMA(yellow_fire, time_point_for_movement_x)]--;

    if(character->args[CMA(yellow_fire, time_point_for_movement_y)] > 0)
        character->args[CMA(yellow_fire, time_point_for_movement_y)]--;

    character->args[CMA(yellow_fire, movement_animation)]++;
}
@}

@d characters_ai_control other characters
@{case character_yellow_fire:
    character_yellow_fire_ai_control(character);
    break;
@}

@d AI functions for different characters @{
static void character_yellow_fire_ai_control(CharacterList *character) {
    int *const angle = &character->args[CMA(yellow_fire, angle)];
    int *const step_of_movement = &character->args[CMA(yellow_fire, step_of_movement)];
    CharacterList *const parent = (CharacterList*)(character->args[CMA(yellow_fire, parent)]);
    int *const move_percent = &character->args[CMA(yellow_fire, move_percent)];
    int *const radius = &character->args[CMA(yellow_fire, radius)];

    @<character_yellow_fire_ai_control is character dead?@>
    @<character_yellow_fire_ai_control counterclockwise fly@>
    @<character_yellow_fire_ai_control remove@>
}
@}

Если у персонажа hp <= 0:
@d character_yellow_fire_ai_control is character dead? @{
if(character->hp <= 0) {
    character_remove_child(parent, CMA(blue_moon_bunny_fairy, child), character, CMA(yellow_fire, next_child));
    character_free(character);
    return;
}
@}
Функция character_remove_child удаляет ребёнка из списка, но не из памяти.

@d Helper functions @{
static void character_remove_child(CharacterList *parent, int child_arg,
    CharacterList *child, int next_child_arg) {
    CharacterList *p = (CharacterList*)(parent->args[child_arg]);

    if(p != NULL && p == child) {
        parent->args[child_arg] = child->args[next_child_arg];
        return;
    }

    while(p != NULL) {
        if((CharacterList*)(p->args[next_child_arg]) == child) {
            p->args[next_child_arg] = child->args[next_child_arg];
            break;
        }

        p = (CharacterList*)(p->args[next_child_arg]);
    }
}
@}
Он удаляет ребёнка child из списка с головой находящейся в parent, но не удаляет из памяти.
child_arg - номер элемента args у parent который является головой списка.
next_child_arg - номер элемента args у child который указывает на следующий child.


Начинаем летать против часовой стрелки и выходить на орбиту:
@d character_yellow_fire_ai_control counterclockwise fly @{
if(*move_percent == 0 || *move_percent == 100) {
    const double deg2rad = M_PI/180.0;
    character->x = parent->x + (int)((*radius)*cos((*angle)*deg2rad));
    character->y = parent->y + (int)((*radius)*sin((*angle)*deg2rad));

    (*angle)--;
    if(*angle == -1)
        *angle = 359;

    if(*radius != 50)
        (*radius)++;
}

character_move_to_angle_and_radius(character, CMA(yellow_fire, move_percent),
    CMA(yellow_fire, time_point_for_movement_x), *angle - 90, 1);
@}
Считаем новое положение огонька и отлетаем на r=1 в перпендикулярном angle направлении.

@d character_yellow_fire_ai_control remove @{
if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
    character->y < -25 || character->y > GAME_FIELD_H + 25) {
    character_free(character);
}
@}

@d characters_draw other characters
@{case character_yellow_fire:
    character_yellow_fire_draw(character);
    break;
@}

@d Draw functions for different characters @{
static void character_yellow_fire_draw(CharacterList *character) {
    int *const angle = &character->args[CMA(yellow_fire, angle)];
    int *const movement_animation = &character->args[CMA(yellow_fire, movement_animation)];
    CharacterList *const parent = (CharacterList*)(character->args[CMA(yellow_fire, parent)]);
    int *const radius = &character->args[CMA(yellow_fire, radius)];

    static int id = -1;

    if(id == -1)
        id = image_load("images/sparks.png");

    const double deg2rad = M_PI/180.0;

    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        10, 7, 10+97, 7+97,
        0, 0.3);

    image_draw_center_t(id,
        GAME_FIELD_X + parent->x + (int)((*radius)*cos((*angle+20)*deg2rad)),
        GAME_FIELD_Y + parent->y + (int)((*radius)*sin((*angle+20)*deg2rad)),
        10, 7, 10+97, 7+97,
        0, 0.1);
}
@}

Повреждение от пуль:
@d damage_calculate other enemy characters
@{case character_yellow_fire:
    if(bullet->bullet_type == bullet_reimu_first)
        character->hp -= 1000;
    break;
@}



Серые завихрения

Похоже что летят по прямой. Не стреляют.

@d Character types
@{character_gray_swirl,
@}

@d Character functions @{
CharacterList *character_gray_swirl_create(int begin_x, int begin_y,
    int end_x, int end_y) {
    CharacterList *character = character_get_free_cell();

    character->x = begin_x;
    character->y = begin_y;
    character->hp = 100;
    character->character_type = character_gray_swirl;
    character->radius = 10;

    character->args[CMA(gray_swirl, time_point_for_movement_x)] = 0;
    character->args[CMA(gray_swirl, time_point_for_movement_y)] = 0;

    character->args[CMA(gray_swirl, end_x)] = end_x;
    character->args[CMA(gray_swirl, end_y)] = end_y;

    character->args[CMA(gray_swirl, movement_animation)] = 0;

    character->args[CMA(gray_swirl, move_percent)] = 0;
    character->args[CMA(gray_swirl, move_begin_x)] = 0;
    character->args[CMA(gray_swirl, move_begin_y)] = 0;

    return character;
}
@}

@d Character public prototypes
@{CharacterList *character_gray_swirl_create(int begin_x, int begin_y, int end_x, int end_y);
@}


@d Character public structs @{
enum {
    CMA(gray_swirl, time_point_for_movement_x) = 0,
    CMA(gray_swirl, time_point_for_movement_y),
    CMA(gray_swirl, end_x),
    CMA(gray_swirl, end_y),
    CMA(gray_swirl, movement_animation),
    CMA(gray_swirl, move_percent),
    CMA(gray_swirl, move_begin_x),
    CMA(gray_swirl, move_begin_y)
};
@}

@d character_set_weak_time_point_x other characters
@{case character_gray_swirl:
    character_gray_swirl_set_weak_time_point_x(character);
    break;
@}

@d character_set_weak_time_point_y other characters
@{case character_gray_swirl:
    character_gray_swirl_set_weak_time_point_y(character);
    break;
@}

@d Different characters set weak time_point functions @{
static void character_gray_swirl_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(gray_swirl, time_point_for_movement_x)] = 5;
}

static void character_gray_swirl_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(gray_swirl, time_point_for_movement_y)] = 5;
}
@}

@d characters_update_all_time_points other characters
@{case character_gray_swirl:
    character_gray_swirl_update_time_points(character);
    break;
@}

@d Update time point for different characters @{
static void character_gray_swirl_update_time_points(CharacterList *character) {
    if(character->args[CMA(gray_swirl, time_point_for_movement_x)] > 0)
        character->args[CMA(gray_swirl, time_point_for_movement_x)]--;

    if(character->args[CMA(gray_swirl, time_point_for_movement_y)] > 0)
        character->args[CMA(gray_swirl, time_point_for_movement_y)]--;

    character->args[CMA(gray_swirl, movement_animation)]++;
}
@}

@d characters_ai_control other characters
@{case character_gray_swirl:
    character_gray_swirl_ai_control(character);
    break;
@}

@d AI functions for different characters @{
static void character_gray_swirl_ai_control(CharacterList *character) {
    int *const end_x = &character->args[CMA(gray_swirl, end_x)];
    int *const end_y = &character->args[CMA(gray_swirl, end_y)];
    int *const move_percent = &character->args[CMA(gray_swirl, move_percent)];

    @<character_gray_swirl_ai_control is character dead?@>
    @<character_gray_swirl_ai_control move@>
    @<character_gray_swirl_ai_control remove@>
}
@}

Если у персонажа hp <= 0:
@d character_gray_swirl_ai_control is character dead? @{
if(character->hp <= 0) {
    character_free(character);
    return;
}
@}

@d character_gray_swirl_ai_control move @{
character_move_to_point(character, CMA(gray_swirl, move_percent),
    CMA(gray_swirl, time_point_for_movement_x), *end_x, *end_y);
@}

@d character_gray_swirl_ai_control remove
@{if(*move_percent == 100)
    if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
        character->y < -25 || character->y > GAME_FIELD_H + 25) {
        character_free(character);
    }
@}

Рисуем серое завихрение:
@d characters_draw other characters
@{case character_gray_swirl:
    character_gray_swirl_draw(character);
    break;
@}

@d Draw functions for different characters @{
static void character_gray_swirl_draw(CharacterList *character) {
    int *const movement_animation = &character->args[CMA(gray_swirl, movement_animation)];

    static int id = -1;

    if(id == -1)
        id = image_load("images/sparks.png");

    if(*movement_animation >= 720)
        *movement_animation = 0;

    image_draw_center_t(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        138, 12, 138+93, 12+93,
        (*movement_animation)/2.0, 0.5);
}
@}

Повреждение от пуль:
@d damage_calculate other enemy characters
@{case character_gray_swirl:
    if(bullet->bullet_type == bullet_reimu_first)
        character->hp -= 1000;
    break;
@}


Wriggle Nightbug

 - похоже что летает беспорядочно. Берёт случайную точку и летит к ней.
 - все время качается вверх-вниз.
 - когда каким типом пуль атакует непонятно

@d Character types
@{character_wriggle_nightbug,
@}

Так как пока непонятно чем отличаются оба жука, то делаем одного. Если они
  отличаются, то можно сделать параметр в конструкторе.

@d Character functions @{
CharacterList *character_wriggle_nightbug_create(int x, int y) {
    CharacterList *character = character_get_free_cell();

    character->x = x;
    character->y = y;
    character->hp = 100;
    character->character_type = character_wriggle_nightbug;
    character->radius = 10;

    character->args[CMA(wriggle_nightbug, time_point_for_movement_x)] = 0;
    character->args[CMA(wriggle_nightbug, time_point_for_movement_y)] = 0;

    character->args[CMA(wriggle_nightbug, move_x)] = 0;
    character->args[CMA(wriggle_nightbug, move_y)] = 0;

    character->args[CMA(wriggle_nightbug, movement_animation)] = 0;

    character->args[CMA(wriggle_nightbug, speed)] = 0;

    character->args[CMA(wriggle_nightbug, step_of_movement)] = 0;

    character->args[CMA(wriggle_nightbug, move_percent)] = 0;
    character->args[CMA(wriggle_nightbug, move_begin_x)] = 0;
    character->args[CMA(wriggle_nightbug, move_begin_y)] = 0;

    character->args[CMA(wriggle_nightbug, time)] = 0;

    return character;
}
@}


@d Character public prototypes
@{CharacterList *character_wriggle_nightbug_create(int x, int y);
@}


@d Character public structs @{
enum {
    CMA(wriggle_nightbug, time_point_for_movement_x) = 0,
    CMA(wriggle_nightbug, time_point_for_movement_y),
    CMA(wriggle_nightbug, move_x),
    CMA(wriggle_nightbug, move_y),
    CMA(wriggle_nightbug, movement_animation),
    CMA(wriggle_nightbug, speed),
    CMA(wriggle_nightbug, step_of_movement),
    CMA(wriggle_nightbug, move_percent),
    CMA(wriggle_nightbug, move_begin_x),
    CMA(wriggle_nightbug, move_begin_y),
    CMA(wriggle_nightbug, time)
};
@}

@d character_set_weak_time_point_x other characters
@{case character_wriggle_nightbug:
    character_wriggle_nightbug_set_weak_time_point_x(character);
    break;
@}

@d character_set_weak_time_point_y other characters
@{case character_wriggle_nightbug:
    character_wriggle_nightbug_set_weak_time_point_y(character);
    break;
@}

@d Different characters set weak time_point functions @{
static void character_wriggle_nightbug_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(wriggle_nightbug, time_point_for_movement_x)] = 10 - (character->args[CMA(wriggle_nightbug, speed)] / 10.1);
}

static void character_wriggle_nightbug_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(wriggle_nightbug, time_point_for_movement_y)] = 10 - (character->args[CMA(wriggle_nightbug, speed)] / 10.1);
}
@}

@d characters_update_all_time_points other characters
@{case character_wriggle_nightbug:
    character_wriggle_nightbug_update_time_points(character);
    break;
@}

@d Update time point for different characters @{
static void character_wriggle_nightbug_update_time_points(CharacterList *character) {
    if(character->args[CMA(wriggle_nightbug, time_point_for_movement_x)] > 0)
        character->args[CMA(wriggle_nightbug, time_point_for_movement_x)]--;

    if(character->args[CMA(wriggle_nightbug, time_point_for_movement_y)] > 0)
        character->args[CMA(wriggle_nightbug, time_point_for_movement_y)]--;

    character->args[CMA(wriggle_nightbug, movement_animation)]++;
}
@}

@d characters_ai_control other characters
@{case character_wriggle_nightbug:
    character_wriggle_nightbug_ai_control(character);
    break;
@}

@d AI functions for different characters @{
static void character_wriggle_nightbug_ai_control(CharacterList *character) {
    int *const move_x = &character->args[CMA(wriggle_nightbug, move_x)];
    int *const move_y = &character->args[CMA(wriggle_nightbug, move_y)];
    int *const speed = &character->args[CMA(wriggle_nightbug, speed)];
    int *const step_of_movement = &character->args[CMA(wriggle_nightbug, step_of_movement)];
    int *const move_percent = &character->args[CMA(wriggle_nightbug, move_percent)];
    int *const time = &character->args[CMA(wriggle_nightbug, time)];

    @<character_wriggle_nightbug_ai_control is character dead?@>
    @<character_wriggle_nightbug_ai_control move to center@>
    @<character_wriggle_nightbug_ai_control wait@>
    @<character_wriggle_nightbug_ai_control choose place@>
    @<character_wriggle_nightbug_ai_control move@>
    @<character_wriggle_nightbug_ai_control remove@>
}
@}

Если у персонажа hp <= 0:
@d character_wriggle_nightbug_ai_control is character dead? @{
if(character->hp <= 0) {
    character_free(character);
    return;
}
@}

Подлетаем к нужной точке:
@d character_wriggle_nightbug_ai_control move to center
@{if(*step_of_movement == 0) {
    character_move_to_point(character, CMA(wriggle_nightbug, move_percent),
        CMA(wriggle_nightbug, time_point_for_movement_x),
        250, 130);

    if(*move_percent == 0) {
        *time = 3000;
        *step_of_movement = 1;
    }
}
@}

@d character_wriggle_nightbug_ai_control wait @{
if(*step_of_movement == 1) {
    (*time)--;

    if(*time == 0)
        *step_of_movement = 2;
}
@}

@d character_wriggle_nightbug_ai_control choose place @{
if(*step_of_movement == 2) {
    int dx, dy;

    do {
        *move_x = rand()%320 + 90;
        *move_y = rand()%70 + 80;

        dx = character->x - *move_x;
        dy = character->y - *move_y;
    } while(dx*dx + dy*dy < 20000);

    *step_of_movement = 3;
}
@}

@d character_wriggle_nightbug_ai_control move @{
if(*step_of_movement == 3) {
    character_move_to_point(character, CMA(wriggle_nightbug, move_percent),
        CMA(wriggle_nightbug, time_point_for_movement_x),
        *move_x, *move_y);

    if(*move_percent == 0) {
        *time = 3000;
        *step_of_movement = 1;
    }
}
@}

@d character_wriggle_nightbug_ai_control remove
@{if(*step_of_movement == 9) {
    if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
        character->y < -25 || character->y > GAME_FIELD_H + 25) {
        character_free(character);
    }
}
@}


@d characters_draw other characters
@{case character_wriggle_nightbug:
    character_wriggle_nightbug_draw(character);
    break;
@}

@d Draw functions for different characters @{
static void character_wriggle_nightbug_draw(CharacterList *character) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/aya.png");

    image_draw_center(id,
        GAME_FIELD_X + character->x,
        GAME_FIELD_Y + character->y,
        0, 0.07);
}
@}

Повреждение от пуль:
@d damage_calculate other enemy characters
@{case character_wriggle_nightbug:
    if(bullet->bullet_type == bullet_reimu_first)
        character->hp -= 1000;
    break;
@}

