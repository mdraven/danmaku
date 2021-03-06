-*- Mode:nuweb -*-

2010 28 июля
начинаю писать концепт даммаку



1)стараюсь делать по KISS
2)делаю тяпляп, лишь бы работало
3)я делаю Touhou, а не универсальный двиг

На будущее: рисую я хреново и долго => лучше не рисовать

==========================================================

Игровые константы.


@o const.h @{
@<License@>

#ifndef _CONST_H_
#define _CONST_H_

@<const.h game field width and height@>
@<const.h game field coodinate@>
@<const.h position of fps indicator@>

#endif
@}


Размер игрового поля, где происходит действие игры:
@d const.h game field width and height @{
#define GAME_FIELD_W 510
#define GAME_FIELD_H 580
@}
Использовать в алгоритмах. Начало в точке (0, 0).


Левый верхний угол игрового поля, где происходит действие игры:
@d const.h game field coodinate @{
#define GAME_FIELD_X 10
#define GAME_FIELD_Y 10
@}
Лучше помещать эти константы в функции вырисовки, а не в алгоритмы.

Константа для линии на которой лежат бонусы:
@d const.h game field coodinate @{
#define GAME_BONUS_LINE 180
@}
Отсчитывается от 0, а не от GAME_FIELD_Y.

@d const.h position of fps indicator @{
#define GAME_FPS_X 725
#define GAME_FPS_Y 570
@}

===========================================================

Набор функция для работы с окном(создание, рисование...).

@i os_specific.w

===============================================================

Переходим к реализации событий.

Итак нажатие клавиш. Тут можно выделить два подхода:

1) Завести функцию get_scan_keydown() она будет говорить какая кнопка была нажата последней и
get_scan_keyup() -- какая была отпущена последней.
2) Завести функцию вида is_keydown(int key) она говорит была ли нажата кнопка key

Первый вариант платформозависим, но проще в реализации. Второй вариант тоже зависим, но не так
сильно.

Улучшим второй вариант, вместо кода кнопки, будем передавать событие. Например вместо Up_Key будем передавать
"двигаться вверх". Функция в ответ возвращает 0 или 1, не была нажата или была.

@o event.h @{
@<License@>

@<keys' events for is_keydown@>
@<is_keydown function prototype@>

@}

Придумаем события:

@d keys' events for is_keydown @{

enum {
    key_fire, key_shadow_character, key_card,
    key_move_left, key_move_right, key_move_up, key_move_down,
    key_menu_up, key_menu_down, key_menu_select, key_escape,
    key_next_dialog
};

@}

Интересно, есть устройства где для перемещению по меню используются другие кнопки? Пусть будут.

@d is_keydown function prototype @{
int is_keydown(int key_type);
@}

Реализация is_keydown:

@o event.c @{
@<License@>

#include <SDL.h>

#include <stdlib.h>

#include "event.h"

@<Key flags@>

int is_keydown(int key_type) {
    SDL_Event event;

    @<Get event@>
    @<Return key state@>

    return 0;
}
@}

Эти флаги устанавливаются в 1, если кнопка нажата и в 0, если нет:
@d Key flags @{
static int fire, shadow_character, card, move_left, move_right, move_up, move_down, escape, next_dialog;
@}

Здесь мы устанавливаем и сбрасываем флаги:
@d Get event @{
while(SDL_PollEvent(&event)) {
    int key = event.type == SDL_KEYDOWN;

    switch(event.key.keysym.sym) {
        case SDLK_z:
            fire = key;
            next_dialog = key;
            break;
        case SDLK_x:
            card = key;
            break;
        case SDLK_LSHIFT:
            shadow_character = key;
            break;
        case SDLK_LEFT:
            move_left = key;
            break;
        case SDLK_RIGHT:
            move_right = key;
            break;
        case SDLK_UP:
            move_up = key;
            break;
        case SDLK_DOWN:
            move_down = key;
            break;
        case SDLK_ESCAPE:
            escape = key;
            break;
    }
}
@}

Тут возвращаем ответ на запрос: установлен флаг у кнопки или нет.

@d Return key state @{
switch(key_type) {
    case key_fire:
        return fire;
    case key_card:
        return card;
    case key_shadow_character:
        return shadow_character;
    case key_move_left:
        return move_left;
    case key_move_right:
        return move_right;
    case key_move_up:
    case key_menu_up:
        return move_up;
    case key_move_down:
    case key_menu_down:
        return move_down;
    case key_escape:
        return escape;
    case key_next_dialog:
        return next_dialog;
    default:
        fprintf(stderr, "\nUnknown key\n");
        exit(1);
}
@}


======================================================

Простой набор функций контроля пересечения прямоугольников:

@o collision.h @{
@<License@>

typedef struct {
    int l, r, t, b;
} Rect;

int is_collide(const Rect *a, const Rect *b);
@}

Реализация:

@o collision.c @{
@<License@>

#include <math.h>

#include "collision.h"

int is_collide(const Rect *a, const Rect *b) {
    int vert = 0, horz = 0;

    if(a->l < b->r && a->l > b->l)
        vert = 1;
    else if(a->r < b->r && a->r > b->l)
        vert = 1;

    if(a->t < b->b && a->t > b->t)
        horz = 1;
    else if(a->b < b->b && a->b > b->t)
        horz = 1;

    if(vert && horz)
        return 1;

    return 0;
}
@}

Пересечение окружностей:
@o collision.h @{
int is_rad_collide(int x1, int y1, int r1, int x2, int y2, int r2);
@}

@o collision.c @{
int is_rad_collide(int x1, int y1, int r1, int x2, int y2, int r2) {
    int dx = x2-x1;
    int dy = y2-y1;
    double dist = sqrt(dx*dx + dy*dy);

    if(dist < r1 + r2)
        return 1;

    return 0;
}
@}

===========================================================

Персонажи.

@i characters.w

===========================================================

Парсер и лексер danmakufu

@i danmakufu_parser_and_lexer.w

===========================================================

Таблица символов и cons'ы

@i ast.w

===========================================================

Danmakufu вычислятор

@i danmakufu.w

===========================================================

Компиляция в байткод для danmakufu

@i danmakufu_bytecode.w

===========================================================

Сборка мусора

@i gc.w

===========================================================

Игровой персонаж.

@o player.h @{
@<License@>

@<Player public structs@>
@<Player public prototypes@>
@}

@o player.c @{
@<License@>

#include <stdlib.h>
#include <stdio.h>

#include "player.h"

@<Player private macros@>
@<Player private structs@>
@<Player private prototypes@>
@<Player functions@>
@}

Координаты игрового персонажа(у обоих форм совпадают):
@d Player public structs @{
extern int player_x;
extern int player_y;
@}

@d Player private structs @{
int player_x;
int player_y;
@}


Тип игрового персонажа:
@d Player private structs @{
static int player_type;
@}

Доступные типы персонажей:
@d Player public structs @{
enum {
    player_reimu, player_yukari,
    player_marisa, player_alice,
    @<Player other player types@>
};
@}

Функция выбора команды из двух персонажей.
Её вызывают когда в игровом меню выбирают какой командой будут играть:
@d Player public prototypes @{
void player_select_team(int team);
@}

@d Player functions @{
void player_select_team(int team) {
    player_team = team;
    player_type = team*2;
    player_update_hitbox_radius();
}
@}
Используем свойство, что первый персонаж в команде имеет номер *2 от номера команды.
Обновим радиус хитбокса.

Функция проверяет тип персонажа и устанавливает нужный радиус хитбокса и радиус сбора
бонусов:
@d Player private prototypes @{
static void player_update_hitbox_radius(void) {
    switch(player_type) {
        case player_reimu:
            player_radius = 10;
            player_get_radius = 20;
            break;
        default:
            fprintf(stderr, "\nUnknown player type\n");
            exit(1);
    }
}
@}

Радиус хитбокса и радиус сбора бонусов:
@d Player public structs @{
extern int player_radius;
extern int player_get_radius;
@}

@d Player private structs @{
int player_radius;
int player_get_radius;
@}



Объявим глобальную переменную в которой будем хранить тип команды:
@d Player private structs @{
static int player_team;
@}

Перечислим возможные команды:
@d Player public structs @{
enum {
    player_team_reimu,
    player_team_marisa,
    @<Player other player's teams@>
};
@}

Функции переключения персонажей:
@d Player public prototypes @{
void player_shadow_character(void);
void player_human_character(void);
@}

@d Player functions @{
void player_shadow_character(void) {
    if(player_type % 2 == 0)
        player_type++;
    player_update_hitbox_radius();
}

void player_human_character(void) {
    if(player_type % 2 == 1)
        player_type--;
    player_update_hitbox_radius();
}
@}
С помощью этих функции выбирается человек или ёкай.
Обновляем радиус хитбокса с помощью player_update_hitbox_radius.

Функция выстрела:
@d Player public prototypes @{
void player_fire(void);
@}

@d Player functions @{
@<Player update fires' time points@>

void player_fire(void) {
    switch(player_type) {
        @<player_fire players' fires@>
        default:
            fprintf(stderr, "\nUnknown player type\n");
            exit(1);
    }

    @<player_fire set weak time point@>
}
@}

@d Player private macros @{
#include "bullets.h"
@}

Атака Рейму:
@d player_fire players' fires @{
case player_reimu:
    if(player_time_point_first_fire == 0)
        bullet_player_reimu_first_create();

    break;
@}
player_time_point_first_fire - очки времени для первого типа пуль, когда они равны 0
персонаж может выпустить одну пулю.

@d Player private structs @{
static int player_time_point_first_fire;
@}

Когда player_time_point_first_fire становится равным 0, нужно увеличить его
чтобы он начал отсчёт до следующего выстрела:
@d player_fire set weak time point @{
if(player_time_point_first_fire == 0)
    player_time_point_first_fire = 80;
@}


Использование карты:
@d Player public prototypes @{
void player_use_card(void);
@}

@d Player functions @{
void player_use_card(void) {
    if(player_powers == 0)
        return;

    switch(player_type) {
        case player_reimu:
            //bullet_player_reimu_card_bullet();
            break;
        @<player_fire other players' card@>
        default:
            fprintf(stderr, "\nUnknown player type\n");
            exit(1);
    }
    player_powers--;
}
@}
Уменьшаем количество карт.

Количество карт:
@d Player public structs @{
extern int player_powers;
@}

@d Player private structs @{
int player_powers;
@}

Очки времени, которые тратятся на перемещение:
@d Player private structs @{
static int player_time_point_for_movement_to_x;
static int player_time_point_for_movement_to_y;
@}

Функции для задания штрафа к time points:
@d Player functions @{
void player_set_weak_time_point_x(void) {
    switch(player_type) {
        case player_reimu:
        case player_marisa:
            player_time_point_for_movement_to_x = 2;
            break;
        default:
            fprintf(stderr, "\nUnknown player type\n");
            exit(1);
    }
}

void player_set_weak_time_point_y(void) {
    switch(player_type) {
        case player_reimu:
        case player_marisa:
            player_time_point_for_movement_to_y = 2;
            break;
        default:
            fprintf(stderr, "\nUnknown player type\n");
            exit(1);
    }
}
@}

Функции перемещения:
@d Player public prototypes @{
void player_move_to(int move_to);
@}

@d Player functions @{
void player_move_to(int move_to) {

    @<player_move_to animation block@>

    if(player_time_point_for_movement_to_x == 0) {
        if(move_to == player_move_to_left) {
            player_set_weak_time_point_x();
            player_x--;
        }
        else if(move_to == player_move_to_right) {
            player_set_weak_time_point_x();
            player_x++;
        }
    }

    if(player_time_point_for_movement_to_y == 0) {
        if(move_to == player_move_to_up) {
            player_set_weak_time_point_y();
            player_y--;
        }
        else if(move_to == player_move_to_down) {
            player_set_weak_time_point_y();
            player_y++;
        }
    }
}
@}

Обнулили счётчик анимации и установили направление движения по горизонтали:
@d player_move_to animation block
@{if(move_to == player_move_to_left)
    player_move_horizontal = -1;
else if (move_to == player_move_to_right)
    player_move_horizontal = 1;
@}
Обнуляется player_move_horizontal в функции рисования.

Перечислим направления перемещения и переменную направления перемещения
по горизонтали:
@d Player public structs @{
enum {
    player_move_to_left, player_move_to_right, player_move_to_up, player_move_to_down
};
@}

@d Player private structs
@{static int player_move_horizontal;
static int player_movement_animation;
@}
player_move_horizontal - флаг используется для анимации движения влево и вправо.
    0 - нет анимации; -1 - движение влево; 1 - движение вправо.
player_movement_animation -- счётчик для анимации инкрементируются,
    так как количество кадров определяется самим персонажем. Обнуляется
    в функции рисования и перемещениея.


Функция которая уменьшает time points, что в итоге приводит к тому, что
персонаж может сдвинуться на позицию и производить выстрелы:
@d Player public prototypes @{
void player_update_all_time_points(void);
@}

@d Player functions @{
void player_update_all_time_points(void) {
    if(player_time_point_for_movement_to_x > 0)
        player_time_point_for_movement_to_x--;

    if(player_time_point_for_movement_to_y > 0)
        player_time_point_for_movement_to_y--;

    if(player_time_point_first_fire > 0)
        player_time_point_first_fire--;

    player_movement_animation++;
}
@}
Так же инкрементирует счётчик анимации.

Рисуем персонажей:
@d Player public prototypes @{
void player_draw(void);
@}

@d Player functions @{
void player_draw(void) {
    switch(player_type) {
        case player_reimu: {
            static int id = -1;
            static int last_toward = 0;

            if(id == -1)
                id = image_load("images/reimu.png");

            if(player_move_horizontal == 0) {
                @<player_draw fly to forward@>
            } else if (player_move_horizontal == -1) {
                @<player_draw fly to left@>
            } else if (player_move_horizontal == 1) {
                @<player_draw fly to right@>
            }

            break;
        }
        default:
            fprintf(stderr, "\nUnknown player type\n");
            exit(1);
    }
}
@}

@d player_draw fly to forward
@{if(player_movement_animation > 300)
    player_movement_animation = 0;

if(player_movement_animation < 100)
    image_draw_center_t(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        2, 3, 2+54, 3+93,
        0, 0.7);
else if (player_movement_animation < 200)
    image_draw_center_t(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        63, 3, 63+54, 3+93,
        0, 0.7);
else
    image_draw_center_t(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        119, 3, 119+54, 3+93,
        0, 0.7);
@}

Движение влево:
@d player_draw fly to left
@{if(last_toward != -1)
    player_movement_animation = 0;

last_toward = player_move_horizontal;
player_move_horizontal = 0;

if(player_movement_animation > 200)
    player_movement_animation = 100;

if(player_movement_animation < 50)
    image_draw_center_t(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        1, 99, 1+55, 99+97,
        0, 0.7);
else if(player_movement_animation < 100)
    image_draw_center_t(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        62, 99, 62+54, 99+87,
        0, 0.7);
else if(player_movement_animation < 150)
    image_draw_center_t(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        124, 100, 124+51, 100+86,
        0, 0.7);
else
    image_draw_center_t(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        177, 100, 177+51, 100+86,
        0, 0.7);
@}
Если в прошлый раз персонаж двигался в другую сторону или летел
    прямо, то обнуляем счётчик анимации. Запоминаем текущее направление
    движения и обнуляем его, так как в функции перемещения этого сделать
    нельзя(вызывается редко). Рисуем анимацию.

@d player_draw fly to right
@{if(last_toward != 1)
    player_movement_animation = 0;

last_toward = player_move_horizontal;
player_move_horizontal = 0;

if(player_movement_animation > 200)
    player_movement_animation = 100;

if(player_movement_animation < 50)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        1, 99, 1+55, 99+97,
        0, 0.7);
else if(player_movement_animation < 100)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        62, 99, 62+54, 99+87,
        0, 0.7);
else if(player_movement_animation < 150)
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        124, 100, 124+51, 100+86,
        0, 0.7);
else
    image_draw_center_t_mirror(id,
        GAME_FIELD_X + player_x,
        GAME_FIELD_Y + player_y,
        177, 100, 177+51, 100+86,
        0, 0.7);
@}
Почти с точностью скопипастчено с движения налево.

Число попыток до того как появится окно продолжений:
@d Player public structs @{
extern int player_players;
@}

@d Player private structs @{
int player_players;
@}


@d Player private macros @{
#include "os_specific.h"
#include "const.h"
#include "bonuses.h"
@}

Сбор бонусов при достижении линии:
@d Player public prototypes @{
void player_bonus_line(void);
@}

@d Player functions @{
void player_bonus_line(void) {
    switch(player_type) {
        @<player_bonus_line players@>
        default:
            fprintf(stderr, "\nUnknown player type\n");
            exit(1);
    }
}
@}

@d player_bonus_line players
@{case player_reimu:
    if(player_y < GAME_BONUS_LINE)
        move_visible_bonuses();
    break;
@}
===========================================================

Пули.

@o bullets.h @{
@<License@>

@<Bullet public macros@>
@<Bullet public structs@>
@<Bullet public prototypes@>
@}

@o bullets.c @{
@<License@>

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "bullets.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"
#include "dlist.h"

@<Bullet private macros@>
@<Bullet private structs@>
@<Bullet private prototypes@>
@<Bullet functions@>
@}

Структура для хранения пуль:
@d Bullet public structs @{
struct BulletList {
    struct BulletList *prev;
    struct BulletList *next;
    struct BulletList *pool;
    int x;
    int y;
    float angle;
    int bullet_type;
    @<Bullet params@>
};

typedef struct BulletList BulletList;
@}

x, y - коодинаты пули
angle - угол поворота
bullet_type - тип

Список пуль:
@d Bullet public structs @{
extern BulletList *bullets;
@}

@d Bullet private structs @{
BulletList *bullets;
@}

Пул свободных элементов для пуль и удалённых элементов:
@d Bullet private structs
@{static BulletList *pool;

static BulletList *pool_free;
static BulletList *end_pool_free;
@}
end_pool_free - ссылка на последний элемент pool_free

BULLET_ALLOC - аллоцируется пуль в самом начале
BULLET_ADD - добавляется при нехватке
@d Bullet private macros @{
#define BULLET_ALLOC 150
#define BULLET_ADD 50
@}

Функция для возвращения выделенной пули обратно в пул:
@d Bullet functions @{
static void bullet_free(BulletList *bullet) {
    if(bullet == bullets)
        bullets = bullets->next;

    if(pool_free == NULL)
        end_pool_free = bullet;

    dlist_free((DList*)bullet, (DList**)(&pool_free));
}
@}
Если освобождаем пулю в самом начале списка bullets, то первой становится
    вторая пуля в списке.
Удаляем в специальный пул(pool_free) так как в том же цикле ячейка пули
    может быть использована снова и тогда ->next и ->prev будут изменены.
Устанавливаем указатель на последний элемент пула end_pool_free, чтобы потом
    легче было соединить с pool(используется то, что dlist_free добавляет элементы
    в начало pool_free).

Соединить pool_free с pool:
@d Bullet functions @{
static void bullet_pool_free_to_pool(void) {
    if(end_pool_free == NULL)
        return;

    end_pool_free->pool = pool;
    pool = pool_free;

    pool_free = NULL;
    end_pool_free = NULL;
}
@}
Соединяет односвязный список pool_free с pool.
Надо вызывать после for обходящих список bullets, но думаю что достаточно
    вызывать только в action.


Типы пуль:
@d Bullet public structs @{
enum {
    bullet_white,
    bullet_red,
    @<Bullet types@>
};
@}

Функция создания белой круглой пули:
@d Bullet functions @{
void bullet_white_create(int x, int y, float angle) {
    BulletList *bullet = bullet_get_free_cell();

    bullet->x = x;
    bullet->y = y;

    bullet->time_point_for_movement_to_x = 0;
    bullet->time_point_for_movement_to_y = 0;

    bullet->angle = angle;
    bullet->bullet_type = bullet_white;
    bullet->move_flag = 0;
}
@}

@d Bullet public prototypes @{
void bullet_white_create(int x, int y, float angle);
@}


bullet_get_free_cell - функция возвращающая свободный дескриптор.
Она устанавливает флаг is_noempty.
@d Bullet functions @{
static BulletList *bullet_get_free_cell(void) {
    if(pool == NULL) {
        int k = (bullets == NULL) ? BULLET_ALLOC : BULLET_ADD;
        int i;

        pool = malloc(sizeof(BulletList)*k);
        if(pool == NULL) {
            fprintf(stderr, "\nCan't allocate memory for bullets' pool\n");
            exit(1);
        }

        for(i = 0; i < k-1; i++)
            pool[i].pool = &(pool[i+1]);
        pool[k-1].pool = NULL;
    }

    bullets = (BulletList*)dlist_alloc((DList*)bullets, (DList**)(&pool));

    return bullets;
}
@}

@d Bullet private prototypes @{
static BulletList *bullet_get_free_cell(void);
@}


Функция создания красной круглой пули:
@d Bullet functions @{
void bullet_red_create(int x, int y, float shift_angle) {
    BulletList *bullet = bullet_get_free_cell();

    bullet->x = x;
    bullet->y = y;

    bullet->time_point_for_movement_to_x = 0;
    bullet->time_point_for_movement_to_y = 0;

    bullet->angle = shift_angle;
    bullet->bullet_type = bullet_red;
    bullet->move_flag = 0;

    bullet->is_enemys = 1;
}
@}
Пуля летит в сторону главного игрового персонажа.
Параметр shift_angle используется для задания отклонения пули от
игрового персонажа. Позже параметр angle начинает использоваться
как обычный угол для пули.
Пуля выпущена врагом, поэтому is_enemys = 1.


@d Bullet public prototypes @{
void bullet_red_create(int x, int y, float shift_angle);
@}



AI пуль:

@d Bullet public prototypes @{
void bullets_action(void);
@}

@d Bullet functions @{
@<Bullet action helpers@>
@<Bullet actions@>

void bullets_action(void) {
    BulletList *bullet;

    for(bullet = bullets; bullet != NULL; bullet = bullet->next) {
        switch(bullet->bullet_type) {
            case bullet_white:
                bullet_white_action(bullet);
                break;
            case bullet_red:
                bullet_red_action(bullet);
                break;
            @<bullets_action other bullets@>
            default:
                fprintf(stderr, "\nUnknown bullet\n");
                exit(1);
        }
    }

    bullet_pool_free_to_pool();
}
@}


Конкретые функции действия пуль.

Белая пуля делает круги:
@d Bullet actions @{
static void bullet_white_action(BulletList *bullet) {
    bullet_move_to_angle_and_radius(bullet, bullet->angle, 10.0);

    if(bullet->move_flag == 0)
        bullet->angle += 5;
}
@}



Красная пуля улетает за край экрана по прямой.

Вычислим угол до персонажа, если пуля не перемещается и передадим в функцию
перемещения:
@d Bullet actions @{
static void bullet_red_action(BulletList *bullet) {
    if(bullet->move_flag == 0) {
        @<bullet_red_action calculate angle@>
    }

    @<bullet_red_action move bullet to player@>
    @<bullet_red_action destroy bullet@>
}
@}

Вычисляем угол между игроком и пулей с помощью арктангенса:
@d bullet_red_action calculate angle @{
int dx = player_x - bullet->x;
int dy = player_y - bullet->y;

bullet->angle += atan2(dy, dx)*(180.0/M_PI);
@}
atan2 корректно обрабатывает dx = 0.
У данного типа пуль параметр angle при создании пули используется как отклонение,
именно поэтому мы прибавляем к нему значение полученое от atan2, а не присваиваем.

Полученный угол angle мы используем чтобы направить пулю в направлении игрока:
@d bullet_red_action move bullet to player @{
bullet_move_to_angle_and_radius(bullet, bullet->angle,
    GAME_FIELD_W * GAME_FIELD_H);
@}
Теперь пуля гарантировано улетит за край экрана.

bullet_move_to_angle_and_radius - переместить пулю по направлению angel на радиус W*H. Когда
пуля достигнет цели, то move_flag сбросится в 0.

Уничтожем пулю когда она вылетит за пределы экрана:
@d bullet_red_action destroy bullet @{
if(bullet->x < -25 || bullet->x > GAME_FIELD_W + 25 ||
    bullet->y < -25 || bullet->y > GAME_FIELD_H + 25)
    bullet_free(bullet);
@}



Сложные пули делаются так: мы создаем "главную" пулю, которая создаёт дочерние.
Дочерние пули имеют номер дескриптора родителя. Родитель меняет у дочерних пуль параметр
step_of_movement и тем самым меняет их поведение.


@d Bullet params @{
int move_flag;
float move_coef;
int move_x;
int move_y;
@}

move_flag - устанавливается в 0, если движение окончено. При начале движения этот флаг проверяется и
если он установлен, то продолжается старое движение. То есть чтобы начать новое движение нужно вначале
установить move_flag в 0, иначе будет продолжаться старое движение.


Это строка долна быть в функциях создания пуль:
bullet->move_flag = 0;


@d Bullet action helpers @{
static void bullet_move_to_angle_and_radius(BulletList *bullet, float angle, float radius) {
    if(bullet->move_flag == 0) {
        const double deg2rad = M_PI/180.0;
        bullet->move_x = bullet->x + (int)(radius*cos(angle*deg2rad));
        bullet->move_y = bullet->y + (int)(radius*sin(angle*deg2rad));
    }

    bullet_move_to_point(bullet, bullet->move_x, bullet->move_y);
}
@}

После того как пуля пройдёт расстояние radius по направлению angle, флаг move_flag сбросится
в 0. Во время движения он будет равен 1. Это можно использовать в скриптах.
radius*cos(angle*deg2rad) пришлось приводить к int так как он давал погрешность и пуля не летала
по кругу, а улетала за край экрана.

@d Bullet private prototypes @{
static void bullet_move_to_point(BulletList *bullet, int x, int y);
@}

@d Bullet functions @{
static void bullet_move_to_point(BulletList *bullet, int x, int y) {
    int dx = bullet->x - x;
    int dy = bullet->y - y;

    float k;

    int fx = 0, fy = 0;

    if(dx == 0 && dy == 0) {
        bullet->move_flag = 0;
        return;
    }

    if(dy == 0)
        k = 100.0;
    else
        k = fabs((float)dx/(float)dy);

    if(bullet->move_flag == 0) {
        bullet->move_flag = 1;
        bullet->move_coef = k;
    }

    if(k < bullet->move_coef)
        fy = 1;
    else if(k > bullet->move_coef)
        fx = 1;
    else {
        fx = 1;
        fy = 1;
    }

    if(fx == 1 && dx != 0) {
        if(dx > 0)
            bullet_move_to(bullet, bullet_move_to_left);
        else
            bullet_move_to(bullet, bullet_move_to_right);
    }

    if(fy == 1 && dy != 0) {
        if(dy > 0)
            bullet_move_to(bullet, bullet_move_to_up);
        else
            bullet_move_to(bullet, bullet_move_to_down);
    }
}
@}

Да, да. И Кнут и прочие плачут кровавыми слезами, так как тут явное нарушение DRY
и этот код повторяет код character_move_to_point. Кроме того будут повторены bullet_move_to
как character_move_to и все сопутствующее функции восстановления time points. Они были
сильно связаны со структорой CharacterList и поэтому я не рискнул делать их универсальными.
Можно лишь порадоваться тому, что здесь они будут static и скрыты внутри bullets.c

@d Bullet private structs @{
enum {
    bullet_move_to_left, bullet_move_to_right, bullet_move_to_up, bullet_move_to_down
};
@}

@d Bullet private prototypes @{
static void bullet_move_to(BulletList *bullet, int move_to);
@}

@d Bullet functions @{
static void bullet_move_to(BulletList *bullet, int move_to) {
    if(bullet->time_point_for_movement_to_x == 0) {
        if(move_to == bullet_move_to_left) {
            bullet_set_weak_time_point_x(bullet);
            bullet->x--;
        }
        else if(move_to == bullet_move_to_right) {
            bullet_set_weak_time_point_x(bullet);
            bullet->x++;
        }
    }

    if(bullet->time_point_for_movement_to_y == 0) {
        if(move_to == bullet_move_to_up) {
            bullet_set_weak_time_point_y(bullet);
            bullet->y--;
        }
        else if(move_to == bullet_move_to_down) {
            bullet_set_weak_time_point_y(bullet);
            bullet->y++;
        }
    }
}
@}

Добавим в структуру пули нужные переменные:

@d Bullet params @{
int time_point_for_movement_to_x;
int time_point_for_movement_to_y;
@}

Зачем нужны эти параметры можно узнать выше в разделе character.

Сейчас определим bullet_set_weak_time_point_x и bullet_set_weak_time_point_y
аналогично character_set_weak_time_point_x и character_set_weak_time_point_y:

@d Bullet private prototypes @{
static void bullet_set_weak_time_point_x(BulletList *bullet);
static void bullet_set_weak_time_point_y(BulletList *bullet);
@}

@d Bullet functions @{
@<Set weak time points for concrete bullets@>
static void bullet_set_weak_time_point_x(BulletList *bullet) {
    switch(bullet->bullet_type) {
        case bullet_white:
            bullet_white_set_weak_time_point_x(bullet);
            break;
        case bullet_red:
            bullet_red_set_weak_time_point_x(bullet);
            break;
        @<bullet_set_weak_time_point_x other bullets@>
        default:
            fprintf(stderr, "\nUnknown bullet\n");
            exit(1);
    }
}

static void bullet_set_weak_time_point_y(BulletList *bullet) {
    switch(bullet->bullet_type) {
        case bullet_white:
            bullet_white_set_weak_time_point_y(bullet);
            break;
        case bullet_red:
            bullet_red_set_weak_time_point_y(bullet);
            break;
        @<bullet_set_weak_time_point_y other bullets@>
        default:
            fprintf(stderr, "\nUnknown bullet\n");
            exit(1);
    }
}
@}

Конкретные реализации функции восстановления очков времени для разных видов пуль:
@d Set weak time points for concrete bullets @{
static void bullet_white_set_weak_time_point_x(BulletList *bullet) {
    bullet->time_point_for_movement_to_x = 1;
}

static void bullet_white_set_weak_time_point_y(BulletList *bullet) {
    bullet->time_point_for_movement_to_y = 1;
}

static void bullet_red_set_weak_time_point_x(BulletList *bullet) {
    bullet->time_point_for_movement_to_x = 5;
}

static void bullet_red_set_weak_time_point_y(BulletList *bullet) {
    bullet->time_point_for_movement_to_y = 5;
}
@}

Функция восстановления time points:
@d Bullet public prototypes @{
void bullets_update_all_time_points(void);
@}

@d Bullet functions @{
void bullets_update_all_time_points(void) {
    BulletList *bullet;

    for(bullet = bullets; bullet != NULL; bullet = bullet->next) {
        if(bullet->time_point_for_movement_to_x > 0)
            bullet->time_point_for_movement_to_x--;

        if(bullet->time_point_for_movement_to_y > 0)
            bullet->time_point_for_movement_to_y--;
    }
}
@}

Нарисуем пули:
@d Bullet public prototypes @{
void bullets_draw(void);
@}

@d Bullet functions @{
@<Concrete functions for bullets drawing@>
void bullets_draw(void) {
    BulletList *bullet;

    for(bullet = bullets; bullet != NULL; bullet = bullet->next) {
        switch(bullet->bullet_type) {
            case bullet_white:
                bullet_white_draw(bullet);
                break;
            case bullet_red:
                bullet_red_draw(bullet);
                break;
            @<bullets_draw other bullets@>
            default:
                fprintf(stderr, "\nUnknown bullet\n");
                exit(1);
        }
    }
}
@}

Рисуем конкретные:
@d Concrete functions for bullets drawing @{
static void bullet_white_draw(BulletList *bullet) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/bullet_green.png");

    image_draw_center(id,
        GAME_FIELD_X + bullet->x,
        GAME_FIELD_Y + bullet->y,
        bullet->angle+90, 0.3);
}

static void bullet_red_draw(BulletList *bullet) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/bullet_green.png");

    image_draw_center(id,
        GAME_FIELD_X + bullet->x,
        GAME_FIELD_Y + bullet->y,
        bullet->angle+90, 0.3);
}
@}

У пуль спрайт повёрнут на 90 градусов, исправляем.

==========================================================

Различные пули.


Веер пуль(spray).

Выпускает веер из 3-х белых круглых пуль по игроку.
Функция создания:
@d Bullet functions @{
void bullet_white_spray3_create(int x, int y) {
    bullet_red_create(x, y, 0.0);
    bullet_red_create(x, y, 4.0);
    bullet_red_create(x, y, -4.0);
}
@}

@d Bullet public prototypes @{
void bullet_white_spray3_create(int x, int y);
@}


Первый вид пуль Рейму, карты летящие вперёд.
@d Bullet functions @{
void bullet_player_reimu_first_create(void) {
    BulletList *bullet = bullet_get_free_cell();

    bullet->x = player_x;
    bullet->y = player_y;

    bullet->time_point_for_movement_to_x = 0;
    bullet->time_point_for_movement_to_y = 0;

    //bullet->angle = shift_angle;
    bullet->bullet_type = bullet_reimu_first;
    bullet->move_flag = 0;

    bullet->is_enemys = 0;
}
@}

@d Bullet public prototypes @{
void bullet_player_reimu_first_create(void);
@}

Добавим тип пули:
@d Bullet types
@{bullet_reimu_first,
@}

Карты летят снизу вверх за пределы экрана:
@d Bullet actions @{
static void bullet_reimu_first_action(BulletList *bullet) {
    @<bullet_reimu_first_action set move_x@>
    @<bullet_reimu_first_action move bullet@>
    @<bullet_reimu_first_action destroy bullet@>
}
@}

Пуля только что была создана, запомним положение персонажа который её выпустил:
@d bullet_reimu_first_action set move_x @{
if(bullet->move_flag == 0)
    bullet->move_x = player_x;
@}

Начнем перемещать пулю в этом направлении:
@d bullet_reimu_first_action move bullet @{
bullet_move_to(bullet, bullet_move_to_up);
@}

Уничтожим пулю когда она выйдет за пределы экрана:
@d bullet_reimu_first_action destroy bullet @{
if(bullet->y < -25)
    bullet_free(bullet);
@}

Добавим функцию поведения пули в диспетчер:
@d bullets_action other bullets
@{case bullet_reimu_first:
    bullet_reimu_first_action(bullet);
    break;
@}

Функции для установки очков времени для пули:
@d Set weak time points for concrete bullets @{
static void bullet_reimu_first_set_weak_time_point_x(BulletList *bullet) {
    bullet->time_point_for_movement_to_x = 1;
}

static void bullet_reimu_first_set_weak_time_point_y(BulletList *bullet) {
    bullet->time_point_for_movement_to_y = 1;
}
@}

Добавим эти функции в диспетчеры:
@d bullet_set_weak_time_point_x other bullets @{
case bullet_reimu_first:
    bullet_reimu_first_set_weak_time_point_x(bullet);
    break;
@}

@d bullet_set_weak_time_point_y other bullets @{
case bullet_reimu_first:
    bullet_reimu_first_set_weak_time_point_y(bullet);
    break;
@}

Рисуем летящие карты Рейму:
@d Concrete functions for bullets drawing @{
static void bullet_reimu_first_draw(BulletList *bullet) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/bullet_white_card.png");

    image_draw_center(id,
        GAME_FIELD_X + bullet->x,
        GAME_FIELD_Y + bullet->y,
        0, 0.6);
}
@}

Добавим функцию рисования в диспетчер:
@d bullets_draw other bullets @{
case bullet_reimu_first:
    bullet_reimu_first_draw(bullet);
    break;
@}

Повреждение от пули:
@d bullet_collide other bullets @{
case bullet_reimu_first:
    if(is_rad_collide(x, y, radius, bullet->x, bullet->y, 10) == 0)
        break;
    bullet_free(bullet);
    return 1;
@}
==========================================================

Повреждения от пуль.


Эту часть попробую написать топорным методом.
Есть функция которая ничего не принимает и не возвращает. Имеет прямой доступ к
списку пуль и персонажей. Сама функция вызывает только функции проверки пересечения
окружностей персонажей и пуль, вычитание жизней и проверку на имунитет к пулям
производит сама.

Так как она распухнет, то поместим её в отдельный модуль.

@o damage.h @{
@<License@>

void damage_calculate(void);
@}

@o damage.c @{
@<License@>

@<Damage header@>

#include "damage.h"

void damage_calculate(void) {
    @<damage_calculate body@>
}
@}

Стандартные хедеры:
@d Damage header @{
#include <stdio.h>
#include <stdlib.h>
@}

Нам нужен доступ к списку пуль и списку вражеских персонажей и персонажем игрока:
@d Damage header @{
#include "characters.h"
#include "bullets.h"
#include "player.h"
@}

Функция перебирает всех персонажей, перебирает все пули,
передаёт хитбоксы персонажей внутрь функции проверки пересечения пули,
фукнция пересечения возвращает истину или ложь, мы проверяем особые случаи повреждения и
отнимаем у персонажа сколько нужно жизней:
@d damage_calculate body @{
BulletList *bullet;
CharacterList *character;

for(bullet = bullets; bullet != NULL; bullet = bullet->next) {
    @<damage_calculate is enemy's bullet?@>

    for(character = characters; character != NULL; character = character->next) {

        @<damage_calculate character hp=0@>

        @<damage_calculate collision check@>
        @<damage_calculate character's damage unique@>

        @<damage_calculate if hp<0 then character died@>
    }
}
@}

Проверяемый персонаж уже мертв и не выводится на экран:
@d damage_calculate character hp=0 @{
if(character->hp <= 0)
    continue;
@}

Если пуля выпущена врагом, то проверим пересечение с персонажем игрока,
иначе перейдем к проверке вражеских персонажей:
@d damage_calculate is enemy's bullet? @{
if(bullet->is_enemys == 1) {
    if(bullet_collide(bullet, player_x, player_y, player_radius) == 1) {
        @<damage_calculate check collision with player@>
    }
    continue;
}
@}

Если пересечение было, то уменьшаем число попыток, если попыток больше нет,
то выводим continue-окно:
@d damage_calculate check collision with player @{
if(player_players == 0) {
    fprintf(stderr, "continue-window stub\n");
    exit(1);
}
player_players--;
@}


Проверка пересечения:
@d damage_calculate collision check @{
if(bullet_collide(bullet, character->x, character->y, character->radius) == 0)
    continue;
@}

Особенности повреждения различных вражеских персонажей:
@d damage_calculate character's damage unique @{
switch(character->character_type) {
    case character_reimu:
//      if(bullet->bullet_type == bullet_red)
            character->hp = 0;
        break;
    @<damage_calculate other enemy characters@>
    default:
        fprintf(stderr, "\nUnknown character\n");
        exit(1);
}
@}

Если у персонажа нет жизней:
@d damage_calculate if hp<0 then character died @{
if(character->hp <= 0) {
    character->hp = 0;
}
@}


Напишем функцию bullet_collide:
@d Bullet public prototypes @{
int bullet_collide(BulletList *bullet, int x, int y, int radius);
@}
Принимает дескриптор пули, координаты хитбокса персонажа и радиус хитбокса.

@d Bullet functions @{
int bullet_collide(BulletList *bullet, int x, int y, int radius) {
    switch(bullet->bullet_type) {
        case bullet_white:
        case bullet_red:
            @<bullet_collide if bullet_red collide@>
        @<bullet_collide other bullets@>
        default:
            fprintf(stderr, "\nUnknown bullet\n");
            exit(1);
    }

    return 0;
}
@}

Проверим красную пулю на пересечение. Если его небыло то выходим из switch, позже
вызовется return 0. Иначе уничтожаем пулю и возвращаем 1.
@d bullet_collide if bullet_red collide @{
if(is_rad_collide(x, y, radius, bullet->x, bullet->y, 3) == 0)
    break;
bullet_free(bullet);
return 1;
@}


Для доступа к is_rad_collide добавим хедер:
@d Bullet private macros @{
#include "collision.h"
@}

Добавим параметр is_enemys:
@d Bullet params @{
int is_enemys;
@}
Если он установлен, то пуля выпущена врагом.

=========================================================

Игровые этажи.

@o levels.h @{
@<License@>

@<Levels prototypes@>
@}

@o levels.c @{
@<License@>

#include <stdio.h>
#include <stdlib.h>

#include "levels.h"

@<Levels macros@>
@<Levels structs@>
@<Levels functions@>
@}

Надо придумать удобный и главное простой скриптовый язык.

Поздний комментарий: флаг is_sleep был удалён из CharacterList

Какие возможности нужно заложить в него?
1.1) установку флага is_sleep у персонажа через N'ое время после установки(или сброса)
    is_sleep у другого персонажа
1.2) установку флага is_sleep у персонажа после смерти другого персонажа
2.1) вызов окна диалогов через N'ое время после установки(или сброса)
    is_sleep у вражеского персонажа
2.2) вызов окна диалогов после смерти вражеского персонажа

Все эти действия можно написать на pure C и при этом не прибегать к сложным механизмам.
Для этого надо сделать всё также как и при реализации ai персонажей или поведения
пуль. Заведем счетчик действий step_of_movement, а вместо move_flag(move_percent) будем использовать
is_sleep различных персонажей.

Напишем пример. Пусть вначале появляются два монстра(mon1, mon2), после их смерти
появляется босс(mon3), а после его смерти появляется диалог. Диалог блокирует выполнение
ai и перемещение пуль, поэтому рассматривать появление монстров после диалога не имеет
смысла.

static int step_of_movement;

void level_dispatcher(void) {
    ...
    level01();
    ...
}

static void level01(void) {
    switch(step_of_movement) {
        case 0:
            character_set_active(mon1);
            character_set_active(mon2);
            step_of_movement++;
            break;
        case 1:
            if(character_get_health_percent(mon1) != 0 ||
                character_get_health_percent(mon2) != 0)
                break;
            character_set_active(mon3);
            step_of_movement++;
            break;
        case 2:
            if(character_get_health_percent(mon3) != 0)
                break;
            dialog_function();
            step_of_movement++;
        .........................
        case 10:
            next_level();
            step_of_movement = 0;
            break;
    }
}

Конечно в такой форме скрипт не очень понятен, но lp позволит сделать его понятнее.
character_get_health_percent, dialog_function, next_level выдуманые функции. Возможно вместо них
будут другие. Например вместо character_get_health_percent можно, в большинстве случаев, использовать
более удобную character_is_died. Диалог скорее всего будет вызываться не dialog_function, а какой-нибудь
функцией с параметром-номером диалога. next_level будет менять глобальную статическую переменную,
скорее всего она же будет делать step_of_movement = 0 и нам не придётся писать это каждый раз самому.

В самом деле, когда нам может понадобиться менять step_of_movement не стандартным образом?
Например мы хотим сделать следующий этаж, продолжением старого этажа, с сохранением всех монстров.
Но для этого мы можем старых монстров сделать глобальными переменными и перенести в следующий этаж.
Кроме того при вызове next_level возможна очистка стеков пуль и персонажей, и чтобы не удалять всех
персонажей, а оставить тех, за кого играем мы, нужно завести в структуре персонажей флаг "не удалять".
Этот флаг нам позволит удалить персонажей, которые нам не пригодились, но небыли убиты или сохранить
убитых, если они нам могут пригодиться(например чтобы их оживить).

В этом примере нет таймера. Мы просто можем отсчитывать step_of_movement, но level может вызываться с
непредсказуемым интервалом. Для удобной работы с таймерами нам нужен стек таймеров, такой же как у
пуль или персонажей. В нем будут храниться таймеры с дескрипторами. В конце этажа таймеры не помеченые
как нужные к сохранению будут удаляться(механизм как у персонажей).
Таймеры нужны не только для скриптов, но я для отсчета действия карт, а возможно и для других игровых
задумок.


===================================================================

Задники.


Задники рисуются в первую очередь. Они трехмерные. На них расположены объекты,
например деревья. Должны отслуживать процент прохождения этажа и менятся при
этом, например изменяется освещённость.


Функция изменения стиля задника:
@d Background public prototypes @{
void background_set_type(int type);
@}

@d Background functions @{
void background_set_type(int type) {
    background_type = type;
    background_animation = 0;
    background_time_points = 0;
}
@}
Стиль задника это не только сам задник, но и его изменения. Например:
    утренний лес, вечерний лес, зимний лес и тд.

background_animation - переменная в которой хранится сдвиг задника при
    анимации;
background_time_points - переменная единиц времени для анимации.
    В отличии от многих случаем они не декрементируются, а наоборот инкрементируются
    так как background_update_animation один и тот же, а задники разные.
@d Background private structs @{
static int background_animation;
static int background_time_points;
@}

В этой переменной будем хранить стиль задника:
@d Background private structs @{
static int background_type;
@}

Список доступных задников:
@d Background public structs @{
enum {
    background_forest,
    @<Background other types@>
};
@}

Функция которая изменяет значение background_time_points и тем самым синхронизирует
анимацию:
@d Background public prototypes @{
void background_update_animation(void);
@}

@d Background functions @{
void background_update_animation(void) {
    if(background_time_points < 20000)
        background_time_points++;
}
@}
Как уже было отмечено, местные time_points инкрементируют.
Введён искусственный потолок в 20000, защита от переполнения "на всякий случай",
    думаю никто не будет ждать 20 секунд между анимацией и поэтому проблем не будет.


Функция рисования задника:
@d Background public prototypes @{
void background_draw(void);
@}

@d Background functions @{
void background_draw(void) {

    window_set_3dbackground_config();

    switch(background_type) {
        @<background_draw backgrounds@>
        default:
            fprintf(stderr, "\nUnknown background\n");
            exit(1);
    }

    window_set_2d_config();
}
@}
window_set_3d_config, window_set_2d_config - удобные настройки окна(OGL) для
вывода соответствующей графики.


Настройки OGL для вывода 3D задника:
@d Background functions @{

static void gluPerspective(GLdouble fovy, GLdouble aspect, GLdouble zNear, GLdouble zFar)
{
   GLdouble xmin, xmax, ymin, ymax;

   ymax = zNear * tan(fovy * M_PI / 360.0);
   ymin = -ymax;

   xmin = ymin * aspect;
   xmax = ymax * aspect;

   glFrustum(xmin, xmax, ymin, ymax, zNear, zFar);
}

static void window_set_3dbackground_config(void) {
//  glClearColor(0, 0, 0, 0);
//  glClear(/*GL_COLOR_BUFFER_BIT |*/ GL_DEPTH_BUFFER_BIT);

//  glDisable(GL_TEXTURE_2D);
//  glEnable(GL_DEPTH_TEST);

    @<window_set_2d_config OGL blend@>

    glViewport(GAME_FIELD_X, GAME_FIELD_Y, GAME_FIELD_W, GAME_FIELD_H);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();

    gluPerspective(45.0f, ((float)GAME_FIELD_W)/((float)GAME_FIELD_H), 1.0f, 500.0f);
    //glFrustum(0, GAME_FIELD_W, GAME_FIELD_H, 0, 1.0, 1000.0);
    //glFrustum(0.0, 10.0, 10.0, 0.0, 1.0, 50.0);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}
@}
Возможно стоит избавится от gluPerspective как от единственного glu.

@d Background private prototypes @{
static void window_set_3dbackground_config(void);
@}


Рисуем лес:
@d background_draw backgrounds @{
case background_forest: {
    static int id = -1;
    float shiftx;

    if(id == -1)
        id = image_load("images/forest.png");

    @<background_draw sync forest@>
    @<background_draw calculate shiftx@>

    glColor3ub(100,100,100);
    @<background_draw draw background of forest@>
    @<background_draw draw trees@>
    glColor3ub(255,255,255);
    break;
}
@}
В shifty будет храниться смещение по оси y.

Анимация каждые 2 мс. для леса:
@d background_draw sync forest
@{if(background_time_points > 2) {
    background_animation++;

    if(background_animation == 1280)
        background_animation = 0;

    background_time_points = 0;
}
@}
Берем в учёт что размер текстуры леса 256x256, умножаем на 5, получаем 1280.

Подсчитаем смещение по оси X:
@d background_draw calculate shiftx @{
if(background_animation >= 0 && background_animation < 180)
    shiftx = (75.0/(128.0*180.0)) * (float)background_animation;
@}
shiftx = (растояние от центра до перегиба по X/(128.0*длина от низа до перегиба по Y))
    128.0 -- длина полигона от центра до края в пикселах.

Дальше я обленился и писал правила "подгонкой":
@d background_draw calculate shiftx
@{else if(background_animation >= 180 && background_animation < 460)
    shiftx = 75.0/128.0;
else if(background_animation >= 460 && background_animation < 650)
    shiftx = 75.0/128.0 - (46.0/(128.0*190.0)) * (float)(background_animation - 460);
else if(background_animation >= 650 && background_animation < 820)
    shiftx = 29.0/128.0;
else if(background_animation >= 820 && background_animation < 950)
    shiftx = 29.0/128.0 + (30.0/(128.0*130.0)) * (float)(background_animation - 820);
else if(background_animation >= 950 && background_animation < 1100)
    shiftx = 59.0/128.0;
else if(background_animation >= 1100)
    shiftx = 59.0/128.0 - (59.0/(128.0*180.0)) * (float)(background_animation - 1100);
@}

Рисуем задник леса:
@d background_draw draw background of forest @{
{
    float shift = background_animation/256.0;
    float sh = shiftx/2.0;

    glTranslatef(0, 0, -1.5);
    glRotatef(-30, 1.0, 0.0, 0.0);
//  glScalef(scale, scale, 0);

    glBindTexture(GL_TEXTURE_2D, image_list[id].tex_id);

    glBegin(GL_QUADS);
        glTexCoord2f(0.0 + sh, 0.0 + shift);
        glVertex2i(-1, -1);

        glTexCoord2f(1.0 + sh, 0.0 + shift);
        glVertex2i(1, -1);

        glTexCoord2f(1.0 + sh, 1.0 + shift);
        glVertex2i(1, 1);

        glTexCoord2f(0.0 + sh, 1.0 + shift);
        glVertex2i(-1, 1);
    glEnd();
}
@}
shift - смещение текстуры, 256 - её размер.
sh - получает делением shiftx на 2, тк отсчёт координат деревьев идёт от центра,
    то есть (-128;+128), а текстур от края (0;+256).

Рисуем деревья:
@d background_draw draw trees @{
{
    int i;

    #include "forest.c"
    static int t1 = sizeof(trees)/sizeof(Tree) - 1;
    int t2;


    static int tree_id[4] = {-1, -1, -1, -1};

    if(tree_id[0] == -1)
        tree_id[0] = image_load("images/tree1.png");
    if(tree_id[1] == -1)
        tree_id[1] = image_load("images/tree2.png");
    if(tree_id[2] == -1)
        tree_id[2] = image_load("images/tree3.png");
    if(tree_id[3] == -1)
        tree_id[3] = image_load("images/tree4.png");

    if(background_animation == 0)
        t1 = sizeof(trees)/sizeof(Tree) - 1;

    for(; t1 > 0; t1--)
        if(trees[t1].y > background_animation)
            break;
    for(t2 = t1; t2 > 0; t2--)
        if(trees[t2].y > background_animation + 260)
            break;

    glLoadIdentity();

    glTranslatef(0, 0, -1.45);
    glRotatef(-30, 1.0, 0.0, 0.0);

    for(i = t2; i < t1; i++) {
        @<background_draw OGL trees@>
    }
}
@}
С координатами деревьев полный отстой. Длина хозяйства 1280. Если кто-то
находится в пределах 0-256, то нужно дублировать прибавив это к 1280.

@d background_draw OGL trees
@{glPushMatrix();
glTranslatef(trees[i].x/128.0 - 1.5 - shiftx,
    (trees[i].y - background_animation)/128.0 - 1.0, 0);
glRotatef(210, 1.0, 0.0, 0.0);
//glScalef(0.1, 0.1, 0);

glBindTexture(GL_TEXTURE_2D, image_list[tree_id[trees[i].type]].tex_id);

glBegin(GL_QUADS);
    glTexCoord2f(0, 0);
    glVertex2f(-0.2, -0.4);

    glTexCoord2f(1, 0);
    glVertex2f(0.2, -0.4);

    glTexCoord2f(1, 1);
    glVertex2f(0.2, 0.1);

    glTexCoord2f(0, 1);
    glVertex2f(-0.2, 0.1);
glEnd();

glPopMatrix();
@}

Создадим структуру Tree в которой будут храниться деревья для задников:
@d Background private structs @{
typedef struct {
    int x;
    int y;
    int type;
} Tree;
@}

Файлы задников:
@o os_specific.h @{
@<Background public structs@>
@<Background public prototypes@>
@}

@o os_specific.c @{
//#include <GL/gl.h>
//#include <GL/glu.h>

//#include <stdio.h>
//#include <stdlib.h>

#include "const.h"
//#include "os_specific.h"

@<Background private structs@>
@<Background private prototypes@>
@<Background functions@>
@}

===================================================================

Таймеры.


@o timers.c @{
@<License@>

#include <stdio.h>
#include <stdlib.h>

#include <SDL.h>

#include "timers.h"

@<Timer private structs@>
@<Timer functions@>
@}


Для начала напишим функцию которая запоминает текущее значение таймера.
Её нужно будет вызывать раз в цикл.
@o timers.h @{
@<License@>

void timer_get_time(void);
@}

@d Timer functions @{
void timer_get_time(void) {
    last = new;
    new = SDL_GetTicks();
    if(last == 0)
        last = new;
}
@}
У нас есть значение new от прошлого вызова функции(new - значение таймера). Присвоим его last:
last = new;

Теперь мы можем поместить в new новое значение таймера(значение текущего вызова функции):
new = SDL_GetTicks();

Так как при первом вызове функции new=0, то и last теперь 0. Это нехорошо, так как new-last очень
большое число. Исправим это:
if(last == 0)
    last = new;


Для функции нужны два поля. В одном будет хранится текущее значение таймера, а в другой прошлое:
@d Timer private structs @{
static int new;
static int last;
@}

Теперь напишем функцию для пересчетай таймеров. Она принимает время которое осталось до
завершения работы таймера, вычитает из него время new-last и возвращает его. Функция
всегда возвращает значение >=0.
@o timers.h @{
int timer_calc(int time);
@}

@d Timer functions @{
int timer_calc(int time) {
    time = time - (new - last);
    if(time < 0)
        time = 0;

    return time;
}
@}

Пример использования:
    static int timer;

    while(1) {
        timer_get_time();

        timer = timer_calc(timer);
        if(timer == 0) {
            printf("Alarm!");
            timer = 100;
        }
    }


=========================================================

Бонусы.

После гигантского временнОго промежутка, продолжаю писать. Поэтому более
категорично относится к ошибкам.(тут вообще смесь кода из bullet и character)

Что можно сказать о бонусах?
    1)Они появляются за пределами экрана или на месте убитых монстров;
    2)Они самостоятельно исчезают попав за край экрана;
    3)Есть специальная линия на экране достигнув которой главный персонаж собирает
все бонусы;
    4)Про уничтожение бонусов я не помню, надо уточнить это;
    5)Скрипты не оказывают влияния на бонусы, и поэтому им не нужен id.
    6)После появления бонусы летят вверх, потому начинаю лететь вниз. А после пересечения
спецлинии по параболе к главному персонажу.

Hint: иероглиф - TEN - точка - 点
    永 - вечность - TO

Отсутствие id делает бонусы похожими на пули.


Позднофикс: сделал с массивом константной длины(около 2048), но он долго перебирал в
    action и жрал 100% CPU, поэтому переделал в модель со списком.

TODO: когда персонаж умирает, то бонусы из него летят веером, пока так сделать нельзя. Надо
  чтобы было можно.

@o bonuses.h @{
@<License@>

@<Bonus public macros@>
@<Bonus public structs@>
@<Bonus public prototypes@>
@}

@o bonuses.c @{
@<License@>

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "bonuses.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"
#include "collision.h"
#include "dlist.h"

@<Bonus private macros@>
@<Bonus private structs@>
@<Bonus private prototypes@>
@<Bonus functions@>
@}

Структура для хранения бонусов:

@d Bonus public structs @{
struct BonusList {
    struct BonusList *prev;
    struct BonusList *next;
    struct BonusList *pool;
    int x;
    int y;
    int type;
    @<Bonuses params@>
};

typedef struct BonusList BonusList;
@}

x, y - координаты бонуса;
type - тип бонуса;

Список бонусов:
@d Bonus public structs @{
extern BonusList *bonuses;
@}

@d Bonus private structs @{
BonusList *bonuses;
@}

BONUS_ALLOC - аллоцировать бонусов в самом начале
BONUS_ADD - добавить при нехватке
@d Bonus private macros @{
#define BONUS_ALLOC 100
#define BONUS_ADD 20
@}

Пул бонусов:
@d Bonus private structs
@{static BonusList *pool;

static BonusList *pool_free;
static BonusList *end_pool_free;
@}
pool_free - сюда попадают удалённые элементы;
end_pool_free - указывает на последний удаленный элемент
Они нужны для того, чтобы удалять элементы при обходе списка for'ом.

Типы бонусов:
@d Bonus public structs @{
enum {
    bonus_small_score,
    bonus_medium_score,
    bonus_power,
    @<Bonus types@>
};
@}
Бонусы дающие очки и бонус увеличивающий мощность.

Функция удаления бонусов:
@d Bonus functions @{
static void bonus_free(BonusList *bonus) {
    if(bonus == bonuses)
        bonuses = bonuses->next;

    if(pool_free == NULL)
        end_pool_free = bonus;

    dlist_free((DList*)bonus, (DList**)(&pool_free));
}
@}
Если бонус который удаляют является первым в списке, то
    сделать первым следующий после удаляемого.

Возвратить удалённые элементы в пул:
@d Bonus functions @{
static void bonus_pool_free_to_pool(void) {
    if(end_pool_free == NULL)
        return;

    end_pool_free->pool = pool;
    pool = pool_free;

    pool_free = NULL;
    end_pool_free = NULL;
}
@}
Вызывать после for в action.

Функции создания бонусов:
@d Bonus functions @{
void bonus_small_score_create(int x, int y) {
    BonusList *bonus = bonus_get_free_cell();

    bonus->x = x;
    bonus->y = y;

    bonus->time_point_for_movement_to_x = 0;
    bonus->time_point_for_movement_to_y = 0;

    bonus->move_percent = 0;
    bonus->move_step = 0;
    bonus->move_to_player = 0;
    bonus->type = bonus_small_score;
}

void bonus_medium_score_create(int x, int y) {
    BonusList *bonus = bonus_get_free_cell();

    bonus->x = x;
    bonus->y = y;

    bonus->time_point_for_movement_to_x = 0;
    bonus->time_point_for_movement_to_y = 0;

    bonus->move_percent = 0;
    bonus->move_step = 0;
    bonus->move_to_player = 0;
    bonus->type = bonus_medium_score;
}

void bonus_power_create(int x, int y) {
    BonusList *bonus = bonus_get_free_cell();

    bonus->x = x;
    bonus->y = y;

    bonus->time_point_for_movement_to_x = 0;
    bonus->time_point_for_movement_to_y = 0;

    bonus->move_percent = 0;
    bonus->move_step = 0;
    bonus->move_to_player = 0;
    bonus->type = bonus_power;
}
@}

@d Bonus public prototypes
@{void bonus_small_score_create(int x, int y);
void bonus_medium_score_create(int x, int y);
void bonus_power_create(int x, int y);
@}


bonus_get_free_cell - функция возвращающая свободный элемент списка.
@d Bonus functions @{
static BonusList *bonus_get_free_cell(void) {

    if(pool == NULL) {
        int k = (bonuses == NULL) ? BONUS_ALLOC : BONUS_ADD;
        int i;

        pool = malloc(sizeof(BonusList)*k);
        if(pool == NULL) {
            fprintf(stderr, "\nCan't allocate memory for bonuses' pool\n");
            exit(1);
        }

        for(i = 0; i < k-1; i++)
            pool[i].pool = &(pool[i+1]);
        pool[k-1].pool = NULL;
    }

    bonuses = (BonusList*)dlist_alloc((DList*)bonuses, (DList**)(&pool));

    return bonuses;
}
@}
Так как dlist_alloc вставляет новый элемент до bonuses, то сделаем его новой головой
    bonuses(для итерации for).

@d Bonus private prototypes
@{static BonusList *bonus_get_free_cell(void);
@}

Поведение бонусов:

@d Bonus public prototypes
@{void bonuses_action(void);
@}

@d Bonus functions @{
@<Bonus action helpers@>
@<Bonus actions@>

void bonuses_action(void) {
    BonusList *bonus;

    for(bonus = bonuses; bonus != NULL; bonus = bonus->next) {
        switch(bonus->type) {
            case bonus_small_score:
                //bonus_small_score_action(bonus);
                bonus_power_action(bonus);
                break;
            case bonus_medium_score:
                //bonus_medium_score_action(bonus);
                bonus_power_action(bonus);
                break;
            case bonus_power:
                bonus_power_action(bonus);
                break;
            @<bonuses_action other bonuses@>
            default:
                fprintf(stderr, "\nUnknown bonus\n");
                exit(1);
        }
    }

    bonus_pool_free_to_pool();
}
@}
После цикла вернём удаленные в нём пули обратно в пул.

Конкретные функции действия пуль.
@d Bonus actions @{
static void bonus_power_action(BonusList *bonus) {
    @<bonus_power_action get@>

    @<bonus_power_action move to player@>

    @<bonus_power_action move up@>
    @<bonus_power_action move down@>
    @<bonus_power_action remove@>
}
@}
Как и обговаривалось ранее, пуля летит вверх(всё медленнее), потом вниз,
а потом её удаляют из списка.
@<bonus_power_action move to player@> - будет описан ниже,
он описывает движение бонуса к игроку, когда он встал на спецлинию.

Персонаж подбирает бонус:
@d bonus_power_action get @{
if(is_rad_collide(player_x, player_y, player_get_radius,
        bonus->x, bonus->y, 5) == 1) {
    bonus_free(bonus);
    player_powers++;
    return;
}
@}

Добавим с структуру бонусов два вспомогательных параметра:
@d Bonuses params
@{int move_percent;
int move_step;
@}
move_percent - процент пути который осталось пройти. В конце пути равен 0.
move_step - тип совершаемого действия, нужен для совершения сложного движения.

При создании бонуса нужно обнулять оба параметра move_percent и move_step.
@d bonus_power_action move up
@{if(bonus->move_step == 0) {
    bonus->move_x = bonus->x;
    bonus->move_y = bonus->y - 40;
    bonus->move_step = 1;
}

if(bonus->move_step == 1) {
    bonus_move_to_slower(bonus, bonus->move_x, bonus->move_y);

    if(bonus->move_percent == 0)
        bonus->move_step = 2;
}
@}
bonus_move_to_slower - двигаться в направлении с замедлением.

@d bonus_power_action move down @{
if(bonus->move_step == 2) {
    bonus_move_to_direction(bonus, bonus_move_to_down);
}
@}

@d bonus_power_action remove @{
if(bonus->x < -25 || bonus->x > GAME_FIELD_W + 25 ||
    /*bonus->y < -25 ||*/ bonus->y > GAME_FIELD_H + 25)
    bonus_free(bonus);
@}



@d Bonuses params @{
int move_x;
int move_y;

int speed;

int time_point_for_movement_to_x;
int time_point_for_movement_to_y;
@}
move_x, move_y - точки куда перемещается бонус.
speed - скорость перемещения(0 - нормальная, 100 - максимальная)
time_point_for_movement_to_x, time_point_for_movement_to_y - очки перемещения,
                перемещение возможно, если этот параметр равен 0.

Напишем функцию востанавливающую time points:
@d Bonus functions @{
@<Set weak time points for concrete bonuses@>
static void bonus_set_weak_time_point_x(BonusList *bonus) {
    switch(bonus->type) {
        case bonus_small_score:
            bonus_small_score_set_weak_time_point_x(bonus);
            break;
        case bonus_medium_score:
            //bonus_medium_score_set_weak_time_point_x(bonus);
            bonus_small_score_set_weak_time_point_x(bonus);
            break;
        case bonus_power:
            //bonus_power_score_set_weak_time_point_x(bonus);
            bonus_small_score_set_weak_time_point_x(bonus);
            break;
        @<bonus_set_weak_time_point_x other bonuses@>
        default:
            fprintf(stderr, "\nUnknown bonus\n");
            exit(1);
    }
}

static void bonus_set_weak_time_point_y(BonusList *bonus) {
    switch(bonus->type) {
        case bonus_small_score:
            bonus_small_score_set_weak_time_point_y(bonus);
            break;
        case bonus_medium_score:
            //bonus_medium_score_set_weak_time_point_y(bonus);
            bonus_small_score_set_weak_time_point_y(bonus);
            break;
        case bonus_power:
            //bonus_power_score_set_weak_time_point_y(bonus);
            bonus_small_score_set_weak_time_point_y(bonus);
            break;
        @<bonus_set_weak_time_point_y other bonuses@>
        default:
            fprintf(stderr, "\nUnknown bonus\n");
            exit(1);
    }
}
@}

@d Set weak time points for concrete bonuses @{
static void bonus_small_score_set_weak_time_point_x(BonusList *b) {
    b->time_point_for_movement_to_x = 5 - (b->speed / 21);
}

static void bonus_small_score_set_weak_time_point_y(BonusList *b) {
    b->time_point_for_movement_to_y = 5 - (b->speed / 21);
}
@}

@d Bonus functions @{
void bonuses_update_all_time_points(void) {
    BonusList *bonus;

    for(bonus = bonuses; bonus != NULL; bonus = bonus->next) {
        if(bonus->time_point_for_movement_to_x > 0)
            bonus->time_point_for_movement_to_x--;

        if(bonus->time_point_for_movement_to_y > 0)
            bonus->time_point_for_movement_to_y--;
    }
}
@}

@d Bonus public prototypes
@{void bonuses_update_all_time_points(void);
@}

Напишем функцию для движения в точку.
@d Bonus functions @{
static void bonus_move_to(BonusList *bonus, int x, int y) {
    float correction_coef;
    float now_coef;
    int fx = 0, fy = 0;

    if(bonus->x == x && bonus->y == y) {
        bonus->move_percent = 0;
        return;
    }


    if(bonus->move_percent == 0) {
        bonus->move_begin_x = bonus->x;
        bonus->move_begin_y = bonus->y;
    }


    {
        int dx, dy;
        float all, last;

        dx = bonus->move_begin_x - x;
        dy = bonus->move_begin_y - y;

        if(dy == 0)
            correction_coef = 100.0;
        else
            correction_coef = fabs((float)dx/(float)dy);


        all = sqrt(dx*dx + dy*dy);

        dx = bonus->x - x;
        dy = bonus->y - y;

        if(dy == 0)
            now_coef = 100.0;
        else
            now_coef = fabs((float)dx/(float)dy);


        last = sqrt(dx*dx + dy*dy);

        bonus->move_percent = (int)((last/all) * 100.0);
    }


    if(now_coef < correction_coef)
        fy = 1;
    else if(now_coef > correction_coef)
        fx = 1;
    else {
        fx = 1;
        fy = 1;
    }

    if(fx == 1 && bonus->x != x) {
        if(bonus->x > x)
            bonus_move_to_direction(bonus, bonus_move_to_left);
        else
            bonus_move_to_direction(bonus, bonus_move_to_right);
    }

    if(fy == 1 && bonus->y != y) {
        if(bonus->y > y)
            bonus_move_to_direction(bonus, bonus_move_to_up);
        else
            bonus_move_to_direction(bonus, bonus_move_to_down);
    }
}
@}
Алгоритм скопирован из уже реализованного алгоритма для character.

@d Bonus private prototypes
@{static void bonus_move_to(BonusList *bonus, int x, int y);
@}

@d Bonuses params @{
int move_begin_x;
int move_begin_y;
@}
Эти параметры тоже из character, они хранят точку начала движения,
по ним находят move_percent.

На его основе сделаем алгоритм движения в точку с замедлением.
@d Bonus functions @{
static void bonus_move_to_slower(BonusList *bonus, int x, int y) {
    bonus_move_to(bonus, x, y);
    bonus->speed = (log(bonus->move_percent+1) / log(101)) * 100.0;
}
@}
Учитываем, что если z < 1, то log отрицательный. Поэтому прибавили 1.

@d Bonus private prototypes
@{static void bonus_move_to_slower(BonusList *bonus, int x, int y);
@}


@d Bonus functions @{
static void bonus_move_to_direction(BonusList *bonus, int move_to) {
    if(bonus->time_point_for_movement_to_x == 0) {
        if(move_to == bonus_move_to_left) {
            bonus_set_weak_time_point_x(bonus);
            bonus->x--;
        }
        else if(move_to == bonus_move_to_right) {
            bonus_set_weak_time_point_x(bonus);
            bonus->x++;
        }
    }

    if(bonus->time_point_for_movement_to_y == 0) {
        if(move_to == bonus_move_to_up) {
            bonus_set_weak_time_point_y(bonus);
            bonus->y--;
        }
        else if(move_to == bonus_move_to_down) {
            bonus_set_weak_time_point_y(bonus);
            bonus->y++;
        }
    }
}
@}

@d Bonus private prototypes
@{static void bonus_move_to_direction(BonusList *bonus, int move_to);
@}

@d Bonus private structs @{
enum {
    bonus_move_to_left, bonus_move_to_right, bonus_move_to_up, bonus_move_to_down
};
@}


@d Bonus public prototypes
@{void bonuses_draw(void);
@}

@d Bonus functions @{
@<Concrete functions for bonuses drawing@>
void bonuses_draw(void) {
    BonusList *bonus;

    for(bonus = bonuses; bonus != NULL; bonus = bonus->next) {
        switch(bonus->type) {
            case bonus_small_score:
                bonus_small_score_draw(bonus);
                break;
            case bonus_medium_score:
                bonus_medium_score_draw(bonus);
                break;
            case bonus_power:
                bonus_power_draw(bonus);
                break;
            @<bonuses_draw other bonuses@>
            default:
                fprintf(stderr, "\nUnknown bonus\n");
                exit(1);
        }
    }
}
@}

@d Concrete functions for bonuses drawing @{
static void bonus_small_score_draw(BonusList *bonus) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/bonus_small_score.png");

    image_draw_center(id,
        GAME_FIELD_X + bonus->x,
        GAME_FIELD_Y + bonus->y,
        0, 0.3);
}

static void bonus_medium_score_draw(BonusList *bonus) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/bonus_medium_score.png");

    image_draw_center(id,
        GAME_FIELD_X + bonus->x,
        GAME_FIELD_Y + bonus->y,
        0, 0.3);
}

static void bonus_power_draw(BonusList *bonus) {
    static int id = -1;

    if(id == -1)
        id = image_load("images/bonuses.png");

    if(bonus->y < 0)
        image_draw_center_t(id,
            GAME_FIELD_X + bonus->x,
            GAME_FIELD_Y + 7,
            0, 33, 32, 52,
            0, 0.8);
    else
        image_draw_center_t(id,
            GAME_FIELD_X + bonus->x,
            GAME_FIELD_Y + bonus->y,
            0, 0, 32, 32,
            0, 0.5);
}
@}

Теперь напишем функцию которая будет вызваться когда необходимо
собрать все видимые бонусы:
@d Bonus public prototypes
@{void get_visible_bonuses(void);
@}

@d Bonus functions @{
void get_visible_bonuses(void) {
    BonusList *bonus;

    for(bonus = bonuses; bonus != NULL; bonus = bonus->next) {
        if(bonus->x < 0 || bonus->y < 0 ||
            bonus->x > GAME_FIELD_W || bonus->y > GAME_FIELD_H)
            continue;

        switch(bonus->type) {
            @<get_visible_bonuses all other bonuses' gets@>
            default:
                fprintf(stderr, "\nUnknown bonus\n");
                exit(1);
        }
    }
}
@}

Функция сбора бонусов при достижении линии:
@d Bonus public prototypes
@{void move_visible_bonuses(void);
@}
Устанавливает видимым бонусам флаг движения:
@d Bonus functions @{
void move_visible_bonuses(void) {
    BonusList *bonus;

    for(bonus = bonuses; bonus != NULL; bonus = bonus->next) {
        if(bonus->x < 0 || bonus->y < 0 ||
            bonus->x > GAME_FIELD_W || bonus->y > GAME_FIELD_H)
            continue;

        switch(bonus->type) {
            @<move_visible_bonuses all other bonuses' gets@>
            default:
                fprintf(stderr, "\nUnknown bonus\n");
                exit(1);
        }
    }
}
@}

@d Bonuses params
@{int move_to_player;
@}
Флаг нужно обнулять в конструкторе и обрабатывать в функции движения(i.e.:bonuses_action),
когда move_to_player установлен, то move_step начинает использоваться особым образом, об этом
ниже. Поэтому следует обнулять move_step при установке move_to_player.

Реализация для бонуса дающего очки:
@d get_visible_bonuses all other bonuses' gets
@{case bonus_small_score:
case bonus_medium_score:
    bonus_free(bonus);
    break;
@}

@d move_visible_bonuses all other bonuses' gets @{
case bonus_small_score:
case bonus_medium_score:
    if(bonus->move_to_player == 1)
        return;
    bonus->move_to_player = 1;
    bonus->move_step = 0;
    break;
@}

Реализация для бонуса дающего power:
@d get_visible_bonuses all other bonuses' gets
@{case bonus_power:
    bonus_free(bonus);
    player_powers++;
    break;
@}

@d move_visible_bonuses all other bonuses' gets @{
case bonus_power:
    if(bonus->move_to_player == 1)
        return;
    bonus->move_to_player = 1;
    bonus->move_step = 0;
    break;
@}

Добавим в функцию bonus_small_score_action реакцию на установленный флаг move_to_player:
@d bonus_power_action move to player
@{if(bonus->move_to_player == 1) {
    if(bonus->move_step == 500)
        bonus->move_step = 0;
    if(bonus->move_step == 0) {
        bonus->speed = 0;
        bonus->move_percent = 0;
        bonus->move_x = player_x;
        bonus->move_y = player_y;
    }

    bonus_move_to(bonus, bonus->move_x, bonus->move_y);

    bonus->move_step++;
    return;
}
@}
Мы используем move_step как счётчик, когда он достигает 500 мы направляем бонус в новую
позицию игрока. Такие сложности нужны потому что из-за особенностей реализации алгоритма
движения по линии, движения персонажа будут грубы из-за постоянной смены конечной точки.

=========================================================

Реализация двусвязного списка.

Жрёт больше памяти, зато быстрее удалить элемент.

@o dlist.h @{
@<License@>

#ifndef __DLIST_H_DANMAKU__
#define __DLIST_H_DANMAKU__

@<Dlist public structs@>
@<Dlist public prototypes@>

#endif /* __DLIST_H_DANMAKU__ */
@}

@o dlist.c @{
@<License@>

#include <stdlib.h>
#include <stdio.h>
#include "dlist.h"

@<Dlist functions@>
@}

@d Dlist public structs @{
struct DList {
    struct DList *prev;
    struct DList *next;
    struct DList *pool;
};

typedef struct DList DList;
@}
pool - односвязный список в пуле свободных элементов.
    Был введён для того чтобы было возможным удаляеть элементы
    из списка при его обходе(не затирается указатель next).

@d Dlist functions @{
/*
DList *dlist_create_pool(int num, size_t size) {
    DList *dl;
    int i;

    dl = malloc(size*num);
    if(dl == NULL) {
        fprintf(stderr, "\nCan't allocate memory\n");
        exit(1);
    }

    for(i = 0; i < num-1; i++)
        dl[i].pool = &(dl[i+1]);
    dl[num-1].pool = NULL;

    return dl;
}*/
@}

@d Dlist public prototypes @{
//DList *dlist_create_pool(int num, size_t size);
@}


Выделяет элемент из пула pool и возвращает его. Если список dlist != NULL, то
    возвращённый элемент будет перед dlist.
@d Dlist functions @{
DList *dlist_alloc(DList *dlist, DList **pool) {
    DList *p;

    if(*pool == NULL) {
        fprintf(stderr, "\nEmpty pool\n");
        exit(1);
    }

    p = *pool;
    *pool = (*pool)->pool;

    if(dlist != NULL) {
        p->next = dlist;
        p->prev = dlist->prev;
        dlist->prev = p;
    } else {
        p->next = NULL;
        p->prev = NULL;
    }

    return p;
}
@}
Функция не аллоцирует пул.

@d Dlist public prototypes
@{DList *dlist_alloc(DList *dlist, DList **pool);
@}

Вернуть элемент в пул. Пул односвязный и поэтому, если pool не первый элемент пула, то
    все предыдущее будут потеряны. Функция возвращает новый первый элемент пула в pool:
@d Dlist functions @{
void dlist_free(DList *el, DList **pool) {
    if(el->next != NULL)
        el->next->prev = el->prev;
    if(el->prev != NULL)
        el->prev->next = el->next;

    el->pool = *pool;
    *pool = el;
}
@}

@d Dlist public prototypes
@{void dlist_free(DList *el, DList **pool);
@}

Проверяет, что это единственный элемент в списке:
@d Dlist functions @{
/*
int dlist_once(const DList *el) {
    if(el->next == NULL && el->prev == NULL)
        return 1;

    return 0;
}*/
@}
если он один, то вернёт 1.

@d Dlist public prototypes
@{//int dlist_once(const DList *el);
@}
dlist_once был нужен, чтобы удалить все элементы в списке. Но вместо этого лучше использовать:
        DList *p;
        for(p = elm->next; p != NULL; p = elm->next)
            xxx_free(p);
        for(p = elm->prev; p != NULL; p = elm->prev)
            xxx_free(p);
        xxx_free(elm);
где elm - это элемент с которого начинаем удалять


Охапка "волшебных" макросов.

Макрос для объявления структуры с именем struct_name;
открывающий
@d Dlist public structs @{
#define DLIST_DEFSTRUCT(struct_name) \
struct struct_name { \
    struct struct_name *prev; \
    struct struct_name *next; \
    struct struct_name *pool;
@}
закрывающий:
@d Dlist public structs @{
#define DLIST_ENDS(struct_name) \
}; \
typedef struct struct_name struct_name;
@}

Макрос создающий глобальные переменные для обслуживания пула:
@d Dlist public structs @{
#define DLIST_SPECIAL_VARS(prefix, struct_name) \
static struct_name *prefix; \
static struct_name *prefix##_pool; \
static struct_name *prefix##_pool_free; \
static struct_name *prefix##_end_pool_free;
@}
prefix - список выделенных(занятых) элементов(далее его вписывают во все поля prefix)
X_pool - список свободных элементов
X_pool_free - список элементов, которые уже удалили, но ещё не освободили(те
  ещё не присоединили к X_pool)
X_end_pool_free - ссылка на последний элемент X_pool_free

Макрос определяющий количество элементов в пуле при создании списка
и количество элементов которое добавится при нехватке:
@d Dlist public structs @{
#define DLIST_ALLOC_VARS(prefix, init_num, add_num) \
static const int prefix##_init = init_num; \
static const int prefix##_add = add_num;
@}
X_init - аллоцируется слотов в самом начале(для локальных списков не имеет значения)
X_add - добавляется при нехватке

Макрос для создания функции удаления элементов,
начало:
@d Dlist public structs @{
#define DLIST_FREE_FUNC(prefix, struct_name) \
static void prefix##_free(struct_name *elm) { \
    if(elm == prefix) \
        prefix = prefix->next; \
\
    if(prefix##_pool_free == NULL) \
        prefix##_end_pool_free = elm; \
@}
если удаляем элемент на который ссылается список элементов(prefix), то
  не забываем исправить prefix.
Если пул удалённых элементов пуст, то elm становится не только первым, но и
  последним.

конец:
@d Dlist public structs @{
#define DLIST_END_FREE_FUNC(prefix, struct_name) \
    dlist_free((DList*)elm, (DList**)(&prefix##_pool_free)); \
}
@}
Присоединяем elm к началу пула удалённых элементов.
Между этими блоками располагается код, который очищает содержимое elm,
  если это требуется.

Макрос создающий функцию которая освобождает удалённые элементы:
@d Dlist public structs @{
#define DLIST_POOL_FREE_TO_POOL_FUNC(prefix, struct_name) \
static void prefix##_pool_free_to_pool(void) { \
    if(prefix##_end_pool_free == NULL) \
        return; \
\
    prefix##_end_pool_free->pool = prefix##_pool; \
    prefix##_pool = prefix##_pool_free; \
\
    prefix##_pool_free = NULL; \
    prefix##_end_pool_free = NULL; \
}
@}

Макрос для функции возвращающей свободный элемент:
@d Dlist public structs @{
#define DLIST_GET_FREE_CELL_FUNC(prefix, struct_name) \
static struct_name *prefix##_get_free_cell(void) { \
    if(prefix##_pool == NULL) { \
        int k = (prefix == NULL) ? prefix##_init : prefix##_add; \
        int i; \
\
        prefix##_pool = malloc(sizeof(struct_name)*k); \
        if(prefix##_pool == NULL) { \
            fprintf(stderr, "\nCan't allocate memory for "#prefix" pool\n"); \
            exit(1); \
        } \
\
        for(i = 0; i < k-1; i++) \
            prefix##_pool[i].pool = &(prefix##_pool[i+1]); \
        prefix##_pool[k-1].pool = NULL; \
    } \
\
    prefix = (struct_name*)dlist_alloc((DList*)prefix, (DList**)(&prefix##_pool)); \
\
    return prefix; \
}
@}


Макросы для локальных списков:

Макрос для создания функции удаления элементов,
начало:
@d Dlist public structs @{
#define DLIST_LOCAL_FREE_FUNC(prefix, struct_name) \
static void prefix##_free(struct_name *elm) { \
    if(prefix##_pool_free == NULL) \
        prefix##_end_pool_free = elm; \
@}
конец:
@d Dlist public structs @{
#define DLIST_LOCAL_END_FREE_FUNC(prefix, struct_name) \
    dlist_free((DList*)elm, (DList**)(&prefix##_pool_free)); \
}
@}

DLIST_POOL_FREE_TO_POOL_FUNC используется и для локальных списоков и для
глобальных.

Макрос для функции возвращающей свободный элемент:
@d Dlist public structs @{
#define DLIST_LOCAL_GET_FREE_CELL_FUNC(prefix, struct_name) \
static struct_name *prefix##_get_free_cell(struct_name *elm) { \
    if(prefix##_pool == NULL) { \
        int k = prefix##_add; \
        int i; \
\
        prefix##_pool = malloc(sizeof(struct_name)*k); \
        if(prefix##_pool == NULL) { \
            fprintf(stderr, "\nCan't allocate memory for "#prefix" pool\n"); \
            exit(1); \
        } \
\
        for(i = 0; i < k-1; i++) \
            prefix##_pool[i].pool = &(prefix##_pool[i+1]); \
        prefix##_pool[k-1].pool = NULL; \
    } \
\
    elm = (struct_name*)dlist_alloc((DList*)elm, (DList**)(&prefix##_pool)); \
\
    return elm; \
}
@}
TODO: несвязывается в глобальный список. А как потом собирать мусор?


=========================================================

Вывод текста в заданный бокс

1) У нас должна быть функция для задания текста который будет выводится
в бокс.
2) Должна быть функция создающая бокс с нужными координатами, размером,
типом шрифта(лучше всего задавать по-имени), свойствами вывода(сразу или
побуквенно или другие). Возвращает дескириптор.
3) Функция рисования бокса.

Верхнее решение слишком сложное. Сделаем функции которые сразу рисуют текст
в боксе нужным шрифтом. Бокс задаётся шириной и начальными координатами.
То есть выводит не весь текст, а только одну строку.
Есть функция, которая рисует столько символов, сколько влезет.
Есть функция возвращает число - позицию первой буквы(не пробела)
  слова, которое не вошло. Возможно стоит ввести комбинацию на неразрывный пробел. Сама функция не рисует.
Придётся где-то хранить дескриптор шрифта, искать в массиве каждый раз долго :(

Например мы делаем диалог персонажей:
Как выводит текст посимвольно? Надо в главный цикл вставить функцию, которая побуквенно
(каждый цикл добавляя букву) будет выводить строку не забывая проверять войдёт слово или нет.
Пример:
 string st = "long long text"
 int pos1 = pos_last_word_of_long_string(st, 120, "font1")
 print(st[:pos1], 0, 0, 120, "font1"))

 int pos2 = pos_last_word_of_long_string(st[pos:], 120, "font1")
 print(st[pos1:pos2], 0, 20, 120, "font1"))
 итд
Так мы выведем несколько строк текста.

Файл шрифта задаётся так:
В первой строке название файла с изображением, такое, чтобы загрузить image_load.
Далее 95 строк вида:
X1 Y1 X2 Y2
В строках закодированы следующие символы: SPC ! \" # $ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? @ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z [ \ ] ^ _ ` a b c d e f g h i j k l m n o p q r s t u v w x y z { | } ~

@o font.h @{
@<License@>

@<Font public prototypes@>
@}

@o font.c @{
@<License@>

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "font.h"
#include "os_specific.h"

@<Font structs@>
@<Font private prototypes@>
@<Font functions@>
@}

Структура в которой хранится шрифт:
@d Font structs @{
#define FONT_FILE_NAME_SIZE 30

typedef struct {
    int x1;
    int y1;
    int x2;
    int y2;
} FontChar;

typedef struct {
    char filename[FONT_FILE_NAME_SIZE];
    int img_desc;
    FontChar chars[95];
} FontList;
@}
На имя файла шрифта(без полного пути) отводится FONT_FILE_NAME_SIZE.
Один символ шрифта хранится в структуре FontChar.
img_desc - дескриптор текстуры.

@d Font structs @{
#define FONT_LIST_LEN 24

static FontList font_list[FONT_LIST_LEN];
static int font_list_pos;
@}
font_list_pos - указывает на позицию, где будет записан следующий загружаемый шрифт.

Скорее всего удалять chars будет операционная система, как и картинки :(


Загрузка шрифта:
@d Font public prototypes @{
int load_font(char *filename);
@}

@d Font functions @{
int load_font(char *filename) {
    char dirname[] = "fonts/";
    char buf[FONT_FILE_NAME_SIZE + sizeof(dirname) + 1];

    strcpy(buf, dirname);
    strcat(buf, filename);

    @<load_font maybe font was loaded@>
    @<load_font else load font@>
}
@}

Шрифт -- не простая картинка, поэтому может быть использован в разных
модулях. Лучше проверить грузи ли мы его. Если этот код не пригодиться,
позже удалю:
@d load_font maybe font was loaded
@{{
    int i;
    for(i=0; i < font_list_pos; i++)
        if(!strcmp(font_list[i].filename, filename))
            return i;
}
@}

@d load_font else load font
@{{
    FontList *font = &font_list[font_list_pos];
    FILE *f;

    @<load_font check font_list_pos@>

    f = fopen(buf, "rt");
    if(f == NULL) {
        fprintf(stderr, "\nCan't open font file: %s\n", filename);
        exit(1);
    }

    @<load_font copy filename@>
    @<load_font load image@>
    @<load_font load chars' struct@>

    fclose(f);
    return font_list_pos++;
}
@}

@d load_font check font_list_pos
@{if(font_list_pos == FONT_LIST_LEN) {
    fprintf(stderr, "\nFont list full\n");
    exit(1);
}
@}

@d load_font copy filename
@{strncpy(font->filename, filename, FONT_FILE_NAME_SIZE);
font->filename[FONT_FILE_NAME_SIZE-1] = '\0';
@}

@d load_font load image
@{{
    char b[100];

    b[sizeof(b)-1] = '\0';
    if(fgets(b, sizeof(b), f) == NULL || b[sizeof(b)-1] != '\0') {
        fprintf(stderr, "\nError with reading image filename in: %s\n", filename);
        exit(1);
    }

    b[strlen(b)-1] = '\0';

    font->img_desc = image_load(b);
}
@}
Чёртова замена '\n' на '\0', и что с ней делать? :(

@d load_font load chars' struct
@{{
    int i;

    for(i=0; i < 95; i++) {
        FontChar *fc = &font->chars[i];
        if(fscanf(f, "%d %d %d %d", &fc->x1, &fc->y1, &fc->x2, &fc->y2) == EOF) {
            fprintf(stderr, "\nError with reading FontChar in: %s\n", filename);
            exit(1);
        }
    }
}
@}

Функция вывода текста:
@d Font public prototypes
@{void print_text(const char *str, int x, int y, int w, int color, int fd);
@}

@d Font functions @{
void print_text(const char *str, int x, int y, int w, int color, int fd) {
    FontList *f = &font_list[fd];
    const char *p;

    w += x;

    for(p = str; *p != '\0'; p++) {
        FontChar *fc = &f->chars[*p - 32];
        int cw = fc->x2 - fc->x1;

        if(x + cw > w)
            break;

        image_draw_corner(f->img_desc, x, y,
            fc->x1, fc->y1, fc->x2, fc->y2, 1.0f, color);
        x += cw;
    }
}
@}

Функция определения какое слово не поместится в бокс:
@d Font public prototypes
@{int pos_last_word_of_long_string(const char *str, int w, int fd);
@}
Возвращает первый символ первого слова, которое не поместится в
бокс. Пробелы символами слова не считаются, остальные символы считаются.
Если помещается всё, то возвращаемое число равно strlen.

@d Font functions @{
int pos_last_word_of_long_string(const char *str, int w, int fd) {
    FontList *f = &font_list[fd];
    int spc, fsw;
    int x = 0;
    int i;

    spc = 0;
    fsw = 0;
    for(i = 0; str[i] != '\0'; i++) {
        FontChar *fc = &f->chars[str[i] - 32];
        int cw = fc->x2 - fc->x1;

        if(str[i] == ' ')
            spc = 1;
        else if(spc == 1) {
            spc = 0;
            fsw = i;
        }


        if(x + cw > w && str[i] != ' ')
            break;

        x += cw;
    }

    return str[i] == '\0' ? i : fsw;
}
@}
spc - флаг того, что раньше встречался пробел. Нужен чтобы находить начало слова.
fsw - first symbol of word - позиция первого символа слова.

=========================================================

Вывод окна диалога между персонажами.

1) Само окно диалога не останавливает действие игры, поэтому надо
поставить if в функции main или у каждого *_action в отдельности;
2) Если взять в учёт, что одновременно используется только одно окно
диалога, то многое упрощается;

Расмотрим две стороны: окно диалога(ОД) и скрипт этажа(СЭ) которое выводит в окно
диалога информацию.

СЭ: должно обнулить окно диалога; выбрать персонажей участвующих в диалоге;
вызвать команду вывода текста, передать в неё текст, персонажа, его эмоции;
вызывать функцию возвращающую информацию(bool) о том закончился диалог или нет;
если закончился, то вывести следующий текст или сообщить о окончательном завершении
диалога. Возможно стоит ввести функцию удаления из диалога.

ОД: должна быть функция типа *_action для вывода текста с анимацией; должен
быть контроль переполнения окна диалога и вывода строки "more...";
должны быть функции для вызова обработчиком нажатия клавишь;
ну и функция вырисовки.

@o dialog.h @{
@<License@>

@<Dialog public structs@>
@<Dialog public prototypes@>
@}

@o dialog.c @{
@<License@>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dialog.h"
#include "os_specific.h"
#include "const.h"
#include "font.h"

@<Dialog private structs@>
@<Dialog private prototypes@>
@<Dialog functions@>
@}

Персонажи:
@d Dialog public structs @{
enum {
    dialog_reimu, @<Dialog other characters@>
};
@}

Эмоции:
@d Dialog public structs @{
enum {
    dialog_normal, dialog_angry, @<Dialog other characters mood@>
};
@}
Эмоции будут храниться не в матрице или дереве, а в функции вырисовки,
которая будет индивидуальной у каждого персонажа(как и в случаях с бонусами,
пулями и тд)

Массивы персонажей с левой и правой стороны:
@d Dialog private structs @{
#define MAX_NUM_OF_CHARS 3

typedef struct {
    int character;
    int position;
    int move;
} Side;

static Side left[MAX_NUM_OF_CHARS];
static Side right[MAX_NUM_OF_CHARS];

static int left_side_point;
static int right_side_point;
@}
MAX_NUM_OF_CHARS - максимальное число персонажей участвующих на каждой
  из сторон;
*_side_point - число персонажей участвующая в данном диалоге;
left,right - список персонажей: для левой стороны персонажи идут по-порядку,
    персонаж под номером left_side_point-1 говорит в данный момент.
    Во время диалога персонажи переставляются в списке. В списке храняться
    числа из enum: dialog_reimu, ...
position - текущая позиция персонажа, для всех отчитывается от 0, а уже при вырисовке
    обращается для правого.
move - точка куда перемещаются персонажи при диалоге, тоже от 0. Если равен *_position,
    то перемещения нет.

Функция обнуления диалога будет приватной, её будет вызывать функция
конца диалога:
@d Dialog functions @{
static void dialog_clear(void) {
    left_side_point = 0;
    right_side_point = 0;
}
@}

Функция добавления персонажей:
@d Dialog functions @{
void dialog_left_add(int character) {
    if(left_side_point == MAX_NUM_OF_CHARS) {
        fprintf(stderr, "\nLeft side of dialog is full\n");
        exit(1);
    }

    left[left_side_point].character = character;
    left[left_side_point].position = left_side_point * SHIFT;
    left[left_side_point].move = left[left_side_point].position;
    left_side_point++;
}

void dialog_right_add(int character) {
    if(right_side_point == MAX_NUM_OF_CHARS) {
        fprintf(stderr, "\nRight side of dialog is full\n");
        exit(1);
    }

    right[right_side_point].character = character;
    right[right_side_point].position = right_side_point * SHIFT;
    right[right_side_point].move = right[right_side_point].position;
    right_side_point++;
}
@}
Эти функции принимают штуки вроде dialog_reimu. Сразу раздаются
позиции, отступ равен 20:
@d Dialog private structs @{
#define SHIFT 20
@}

@d Dialog public prototypes @{
void dialog_left_add(int character);
void dialog_right_add(int character);
@}

Функция добавления нового текста:
@d Dialog functions @{
void dialog_msg(char *text, int character, int mood) {
    Side *side;
    int *side_point;
    Side *other_side;
    int *other_side_point;
    int i;

    if(dialog_says == 1)
        return;

    @<dialog_msg find char, set pointers and get i@>
    @<dialog_msg set side@>
    @<dialog_msg set other_side@>

    speaker = character;
    speaker_mood = mood;

    strncpy(message, text, sizeof(message));
    message[sizeof(message)-1] = '\0';
    message_len = strlen(message);

    message_point = 0;
    begin_pos = 0;

    if(dialog_mode == 0) {
        anim_mode = 1;
        anim_step = 0;
    }

    dialog_mode = 1;
    dialog_says = 1;
}
@}
Стоит обратить внимание, что анимация появления окна включается, только
если это новый диалог(те dialog_mode = 0).

@d Dialog public structs @{
extern int dialog_mode;
extern int dialog_says;
@}
dialog_mode - значит, что находимся в режиме диалога.
dialog_says - сообщение персонажа ещё не вывелось до конца.

@d Dialog private structs @{
static int speaker;
static int speaker_mood;
static char message[1024];
static int message_len;
static int message_point;
static int begin_pos;

int dialog_mode;
int dialog_says;

static int anim_mode;
static int anim_step;
@}
speaker - тот кто говорит в данный момент. Сравниваем speaker с left[left_side_point-1].character
    и с right[right_side_point-1].character и таким образом узнаём сторону.
message_point - позиция до которой выводится текст(для посимвольного вывода при анимации)
    когда message_point == message_len, то это значит, что весь текст персонажа выведен на
    экран и можно переходить к следующему персонажу.
begin_pos - позиция с которой выводится текст(для перелистывания страниц при выводе more...)
dialog_mode и dialog_says описаны выше.
anim_mode - режим анимации диалога(0 - никакая; 1 - окно диалога появляется; 2 - окно диалога
    исчезает)
anim_step - шаг анимации появления и исчезновения окна диалога и персонажей. От 0 до 100.


Найдем char и заполним указатели для стороны где он есть
и где его нет:
@d dialog_msg find char, set pointers and get i
@{for(i = 0; i < left_side_point; i++)
    if(left[i].character == character) {
        side = left;
        side_point = &left_side_point;
        other_side = right;
        other_side_point = &right_side_point;
        break;
    }

if(i == left_side_point) {
    for(i = 0; i < right_side_point; i++)
        if(right[i].character == character) {
            side = right;
            side_point = &right_side_point;
            other_side = left;
            other_side_point = &left_side_point;
            break;
        }

    if(i == right_side_point) {
        fprintf(stderr, "\nUnknown side of dialog\n");
        exit(1);
    }
}
@}
В i будет хранится его позиция.

Переставим элементы side -- стороны, где находится char.
Бывший speaker пойдёт к остальным персонажам, новый на
передний план:
@d dialog_msg set side
@{{
    Side s = side[i];
    for(i++; i < *side_point; i++) {
        side[i-1] = side[i];
        side[i-1].move = (i-1) * SHIFT;
    }

    side[*side_point - 1] = s;
    side[*side_point - 1].move = *side_point * SHIFT + SHIFT;
}
@}

Вернем speaker'а противоположной стороны на его место:
@d dialog_msg set other_side
@{for(i = 0; i < *other_side_point; i++)
    other_side[i].move = i * SHIFT;
@}

После того как вызвали dialog_msg проиходит следующее:
 персонаж который будет говорить движется на место говорящего(последнего),
 тот кто говорил -- движется на место предпоследнего,
 те кто были после того кого вызвали смещаются на его место.

@d Dialog public prototypes @{
void dialog_msg(char *text, int character, int mood);
@}

Функция действия будет увеличивать число символов, которые будет выводить
функция рисования и будет двигать персонажей:
@d Dialog functions @{
void dialog_action(void) {
    int i;

    @<dialog_action check dialog_mode flag@>
    @<dialog_action dialog open & close animation@>
    @<dialog_action move characters@>
    @<dialog_action set message_point@>
}
@}

Проверка, что находимся в режиме диалога:
@d dialog_action check dialog_mode flag
@{if(dialog_mode == 0)
    return;
@}

Очки анимации появления и исчезновения окна диалога и персонажей:
@d dialog_action dialog open & close animation
@{if(anim_point == 0) {
    switch(anim_mode) {
        @<dialog_action anim_mode == 1@>
        @<dialog_action anim_mode == 2@>
    }
    anim_point = 70;
}
@}

@d Dialog private structs
@{static int anim_point;
@}

Появление диалога:
@d dialog_action anim_mode == 1
@{case 1:
    if(anim_step < 100)
        anim_step++;
    else
        anim_mode = 0;
    break;
@}
Изначально anim_step = 0.

Исчезновение диалога:
@d dialog_action anim_mode == 2
@{case 2:
    if(anim_step > 0)
        anim_step--;
    else {
        anim_mode = 0;
        dialog_true_end();
    }
    break;
@}
Изначально anim_step = 100.
Из-за анимации завершения мы не можем очистить всё в функции
    dialog_end и откладываем это до завершения анимации исчезновения.
    Всё очищается в функции dialog_true_end.

Перемещаем фигурки персонажей:
@d dialog_action move characters
@{if(character_move_point == 0) {
    for(i = 0; i < left_side_point; i++)
        if(left[i].position < left[i].move)
            left[i].position++;
        else if(left[i].position > left[i].move)
            left[i].position--;

    for(i = 0; i < right_side_point; i++)
        if(right[i].position < right[i].move)
            right[i].position++;
        else if(right[i].position > right[i].move)
            right[i].position--;

    character_move_point = 20;
}
@}

@d Dialog private structs
@{static int character_move_point;
@}
Счётчик используемый при перемещении персонажей в диалоге. Когда
    он равен 0, картинки сдвигаются.

Добавляем единицу к счётчику выводимых букв:
@d dialog_action set message_point
@{if(message_point_point == 0) {
    if(message_point < message_len && more_flag == 0)
        message_point++;

    message_point_point = 40;
}
@}

@d Dialog private structs
@{static int message_point_point;
@}
Счётчик используемый при увеличении числа букв, которые выводятся в окне
    диалога. Когда он равен 0, выводится следующая буква.

@d Dialog public prototypes
@{void dialog_action(void);
@}

Функция обновления очков времени:
@d Dialog functions @{
void dialog_update_all_time_points(void) {
    if(anim_point > 0)
        anim_point--;

    if(character_move_point > 0)
        character_move_point--;

    if(message_point_point > 0)
        message_point_point--;
}
@}

@d Dialog public prototypes
@{void dialog_update_all_time_points(void);
@}

Рисуем окно диалога:
@d Dialog functions @{
void dialog_draw(void) {

    if(dialog_mode == 0)
        return;

    @<dialog_draw draw chars@>
    @<dialog_draw draw background@>
    @<dialog_draw draw characters@>
}
@}

@d Dialog public prototypes
@{void dialog_draw(void);
@}

Выводим задник с учётом анимации появления и исчезновения:
@d dialog_draw draw background
@{{
    static int id = -1;

    if(id == -1)
        id = image_load("images/dialog.png");

    image_draw_corner(id, 20, 650 - anim_step*2, 0, 0, 256, 66, 1.9f, color_white);
}
@}

Выводим символы по одному, учитываем строки, если надо пишем more...:
@d dialog_draw draw characters
@{{
    int line;
    int pos;
    static int fd = -1;

    if(fd == -1)
        fd = load_font("big_font1.txt");

    line = 0;
    pos = begin_pos;
    while(1) {
        int new_pos;

        new_pos = pos + pos_last_word_of_long_string(&message[pos], 465, fd);

        @<dialog_draw draw characters step by step@>

        if(more_flag == 1)
            break;

        if(new_pos == message_len) {
            break;
        }

        pos = new_pos;
        line++;
    }
}
@}
pos_last_word_of_long_string возвращает первый символ слова, который не вошёл в строку.
В эту функцию передают message c позиции pos, те с прошлого значения new_pos. Так
    мы будем узнавать откуда выводить новую строку.
В самом начале pos инициализируется значением begin_pos, чтобы вывести следующую страницу,
    если на прошлой было "more...".
Если были выведены все буквы или "more...", то перестанем выводить текст.
message_len - длина message.

Кроме строк нужно учитывать, что мы выводим посимвольно:
@d dialog_draw draw characters step by step
@{{
    int cpos = message_point;
    char c;

    if(new_pos > cpos) {
        c = message[cpos];
        message[cpos] = '\0';
    }

    @<dialog_draw draw characters in line@>

    if(new_pos > cpos) {
        message[cpos] = c;
        break;
    }
}
@}
Если следующая строка начинается с той позиции, которую мы не
выводим на экран, то это значит, что вывод сообщения прерывается
на текущей строке и мы должны поставить терминатор. А после вывода
вернуть затёртую букву назад.
cpos нужен так как значение message_point изменится.

Ставим терминатор там, где прерывается строка:
@d dialog_draw draw characters in line
@{{
    char b;
    b = message[new_pos];
    message[new_pos] = '\0';

    @<dialog_draw print more... or message@>

    message[new_pos] = b;
}
@}
Не забываем восстановить затёртый символ.

Выводим more... или строку с учётом анимации:
@d dialog_draw print more... or message
@{more_flag = 0;
if(new_pos != message_len && line == 3) {
    print_text("more...", 30, 655 + 30*line - anim_step*2, 465, color_green, fd);
    more_flag = 1;
    message_point = pos;
} else
    print_text(&message[pos], 30, 655 + 30*line - anim_step*2, 465, color_red, fd);
@}
more... выводится на 4-й строке при условии, что существует и 5-я строка.
Нумерация строк идёт с 0, чтобы не вычитать 1 при умножении.
При выводе строк(внутри while(1)) more_flag изменяет своё значение, но после выхода
    из цикла по нему можно однозначно сказать выведен "more..." или нет.
Здесь просходит присваивание message_point значения pos по следующей причине:
    частота изменения message_point не связана с частатой вырисовки и когда счётчик
    fps позволит нарисовать строку message_point может измениться несколько раз.
    Пример: "hello world !!!" пусть первое слово на одной странице, второе на второй странице.
    После того как было выведено hello message_point обновился два раза и указывает на "o" в
    "world". Так как pos не менялся на экран выведется "hello\nmore...",
    а будет указывать на "w" -- первую букву "world", те pos != message_point.
        Кстати, это подтверждается уменьшением времени инкрементации message_point.
    В отличии от опережения в отстовании message_point нет ничего страшного, так как строка
    не выводится(вместо неё надпись "more..."), то установка в pos ничего не изменит.

@d Dialog private structs
@{static int more_flag;
@}
Если more_flag установлен, то можно перелистнуть страницу.

Сделаем функцию с помощью которой можно перелистывать сообщения:
@d Dialog functions @{
void dialog_next_page(void) {
    if(dialog_mode == 0)
        return;

    if(dialog_says == 0)
        return;

    if(message_point == message_len)
        dialog_says = 0;
    else if(more_flag == 1) {
        begin_pos = message_point;
    }
}
@}
Если выведены на экран все буквы сообщения, то установим dialog_says в 0.
Если появилась надпись "more...", то установим позицию начала выводимого
    сообщения(begin_pos) и позицию до которой текст будет выводится(message_point)
    для анимации посимвольного вывода.

@d Dialog public prototypes
@{void dialog_next_page(void);
@}

Эту функцию вызывают, чтобы закончить диалог:
@d Dialog public prototypes
@{void dialog_end(void);
@}

@d Dialog functions @{
void dialog_end(void) {
    if(dialog_says == 1)
        return;

    if(anim_mode != 0)
        return;

    anim_mode = 2;
    anim_step = 100;
}
@}

Так как dialog_end вызвает анимацию завершения, то
мы должны удалить отложено. Эта функция выполняется после завершения
анимации исчезновения окна диалога:
@d Dialog private prototypes
@{static void dialog_true_end(void);
@}

@d Dialog functions @{
static void dialog_true_end(void) {
    dialog_mode = 0;
    dialog_clear();
}
@}
После выполнения функции dialog_mode = dialog_says = anim_mode = 0.

Выводим персонажей:
@d dialog_draw draw chars
@{{
    int i;

    for(i = 0; i < left_side_point; i++) {
        @<dialog_draw posx for left@>

        switch(left[i].character) {
            @<dialog_draw left side characters@>
            default:
                fprintf(stderr, "\nUnknown character on left side of dialog\n");
                exit(1);
        }
    }

    for(i = 0; i < right_side_point; i++) {
        @<dialog_draw posx for right@>

        switch(right[i].character) {
            @<dialog_draw right side characters@>
            default:
                fprintf(stderr, "\nUnknown character on right side of dialog\n");
                exit(1);
        }
    }
}
@}

@d dialog_draw posx for left
@{int x = -180 + left[i].position + anim_step*2;
@}
В переменной x хранится смещения относительно левой стороны экрана.

@d dialog_draw posx for right
@{int x = 575 - right[i].position - anim_step*2;
@}


Выводим Рейму с левой стороны:
@d dialog_draw left side characters
@{case dialog_reimu: {
    static int normal = -1;
    static int angry = -1;

    if(normal == -1)
        normal = image_load("images/reimu_normal_l.png");

    if(angry == -1)
        angry = image_load("images/reimu_angry_l.png");


    if(left[i].move == left[i].position && speaker == dialog_reimu)
        switch(speaker_mood) {
            case dialog_normal:
                image_draw_corner(normal, x, 250, 0, 0, 128, 256, 1.0f, color_white);
                break;
            case dialog_angry:
                image_draw_corner(angry, x, 250, 0, 0, 128, 256, 1.0f, color_white);
                break;
            default:
                fprintf(stderr, "\nUnknown Reimu's mood\n");
                exit(1);
        }
    else
        image_draw_corner(normal, x, 250, 0, 0, 128, 256, 1.0f, color_white);

    break;
}
@}


Выводим Юкари с левой стороны:
@d dialog_draw left side characters
@{case dialog_yukari: {
    static int normal = -1;

    if(normal == -1)
        normal = image_load("images/yukari_normal_l.png");

    image_draw_corner(normal, x, 250, 0, 0, 128, 256, 1.0f, color_white);
    break;
}
@}

@d Dialog other characters
@{dialog_yukari,@}

Выводим Марису с правой стороны:
@d dialog_draw right side characters
@{case dialog_marisa: {
    static int normal = -1;

    if(normal == -1)
        normal = image_load("images/marisa_normal_r.png");

    image_draw_corner(normal, x, 250, 0, 0, 128, 256, 1.0f, color_white);
    break;
}
@}

@d Dialog other characters
@{dialog_marisa,@}


Пример использования:
    static int c = 0;

    if(c == 0) {
        dialog_left_add(dialog_reimu);
        dialog_right_add(dialog_marisa);
        dialog_msg("Hi! How are you?", dialog_reimu, dialog_normal);
        c++;
    } else if (c == 1 && dialog_says == 0) {
        dialog_msg("Great!", dialog_marisa, dialog_normal);
        c++;
    }
    dialog_end();

=========================================================

Игровая панель с информацией.


@o panel.h @{
@<License@>

@<Panel public prototypes@>
@}

@o panel.c @{
@<License@>

#include "os_specific.h"
#include "player.h"
#include "const.h"
#include "font.h"

@<Panel private structs@>
@<Panel private prototypes@>
@<Panel functions@>
@}

@d Panel functions @{
void panel_draw(void) {
    static int dialog = -1;
    static int fd = -1;


    if(dialog == -1)
        dialog = image_load("images/dialog.png");

    if(fd == -1)
        fd = load_font("big_font1.txt");

    @<panel_draw draw noise@>
    @<panel_draw draw road@>
    @<panel_draw draw moon@>
    @<panel_draw draw score@>
    @<panel_draw draw player & spell@>
    @<panel_draw draw power,graze,point,time@>
}
@}

@d panel_draw draw noise
@{{
    int i, j;

    @<panel_draw draw horizontal borders@>
    @<panel_draw draw vertical borders@>
    @<panel_draw draw bars@>
}
@}
Далее идут участки, которые нужно переписать после изменения GAME_FIELD_*, а всё благодаря
моей лени :(

Горизонтальные полоски сверху и снизу:
@d panel_draw draw horizontal borders
@{for(i = 0; i < 800; i+=58) {
    image_draw_corner(dialog, i, 0, 0, 116, 0+58, 116+GAME_FIELD_Y, 1.0f, color_white);
    image_draw_corner(dialog, i, 29*20+10, 0, 116+10, 0+58, 116+29, 1.0f, color_white);
}
@}
58 и 29 - ширина и высота текстуры. 800 на 600 - разрешение экрана.
0 и 116 - положение блока текстуры на большой текстуре.
116+GAME_FIELD_Y - обрезка текстуры игровым полем, а оно начинается с позиции GAME_FIELD_Y.
29*20 = 580 - самый нижний блок текстуры, та что ниже уже не видна, но
    GAME_FIELD_Y+GAME_FIELD_H = 590, следовательно нужно отрезать 10 пикселей.
    Смещаемся на 10 ниже - 29*20+10, отрезаем 10 сверху у текстуры 116+10.

Вертикальные полосы слева и справа:
@d panel_draw draw vertical borders
@{for(j = 0; j < 600; j+=29) {
    image_draw_corner(dialog, 0, j, 0, 116, 0+GAME_FIELD_X, 116+29, 1.0f, color_white);
    image_draw_corner(dialog, 58*8+56, j, 56, 116, 0+58, 116+29, 1.0f, color_white);
}
@}
См. про горизрнтальные полосы выше.
58*8 = 464, а GAME_FIELD_X+GAME_FIELD_W = 520, те 520-464 = 56 и надо
    нарисовать оставшиеся 2 пикселя.

Заполняем оставшееся место:
@d panel_draw draw bars
@{for(i = 58*9; i < 800; i+=58)
    for(j = 0; j < 600; j+=29)
        image_draw_corner(dialog, i, j, 0, 116, 0+58, 116+29, 1.0f, color_white);
@}

@d panel_draw draw road
@{image_draw_corner(dialog, 630, 250, 100, 85, 100+56, 85+161, 2.0f, color_white);
@}

@d panel_draw draw moon
@{image_draw_corner(dialog, 625, 370, 2, 155, 98, 252, 1.0f, color_white);
@}

HiScore & Score:
@d panel_draw draw score
@{image_draw_corner(dialog, 540, 60, 167, 71, 167+77, 71+16, 1.0f, color_white);
image_draw_corner(dialog, 540, 90, 167, 95, 167+55, 95+15, 1.0f, color_white);

{
    char b[2];
    int i;

    b[1] = '\0';

    for(i = 0; i < 10; i++) {
        b[0] = 0+'0';
        print_text(b, 630+16*i, 55, 90, color_white, fd);
        print_text(b, 630+16*i, 55+30, 90, color_white, fd);
    }
}
@}

@d panel_draw draw player & spell
@{image_draw_corner(dialog, 540, 140, 167, 117, 167+65, 117+21, 1.0f, color_white);
image_draw_corner(dialog, 540, 170, 167, 140, 167+49, 140+21, 1.0f, color_white);

{
    int i;

    for(i = 0; i < 6; i++)
        image_draw_corner(dialog, 630+22*i, 137, 1, 69, 1+32, 69+32, 0.7f, color_white);

    for(i = 0; i < 7; i++)
        image_draw_corner(dialog, 630+22*i, 167, 40, 68, 40+33, 68+33, 0.7f, color_white);
}
@}

@d panel_draw draw power,graze,point,time
@{image_draw_corner(dialog, 540, 220, 167, 160, 167+62, 160+19, 1.0f, color_white);
image_draw_corner(dialog, 540, 250, 168, 187, 168+57, 187+15, 1.0f, color_white);
image_draw_corner(dialog, 540, 280, 167, 209, 167+53, 209+16, 1.0f, color_white);
image_draw_corner(dialog, 540, 310, 167, 232, 167+50, 232+16, 1.0f, color_white);
@}

@d Panel public prototypes
@{void panel_draw(void);
@}

=========================================================
Основной файл игры:

@o main.c @{
@<License@>

#include <stdlib.h>
#include <stdio.h>

#include "os_specific.h"
#include "event.h"
#include "collision.h"
#include "characters.h"
#include "bullets.h"
#include "timers.h"
#include "damage.h"
#include "player.h"
#include "bonuses.h"
#include "const.h"
#include "font.h"
#include "dialog.h"
#include "panel.h"

@<Main functions@>
@}


Функция main:

@d Main functions @{

int main(void) {
    @<main variables@>

    window_init();
    window_create();

    player_x = GAME_FIELD_W/2;
    player_y = GAME_FIELD_H - GAME_FIELD_H/8;

    player_select_team(player_team_reimu);

    {
        int i;
        for(i = 0; i < 1; i++) {
            //CharacterList *character = character_blue_moon_fairy_create(30*i, 10, 30*i+100, 200, 30*i+150, -30);
        }

        CharacterList *character = character_blue_moon_bunny_fairy_create(100, 30, 100, 200, 550, 250);
    }

/*  {
        int i, j;
        for(i=0; i<1; i++)
            for(j=0; j<2; j++)
                bullet_red_create(100+i*10, 100+j*10);
    }*/

    //dialog_left_add(dialog_yukari);
    //dialog_left_add(dialog_reimu);
    //dialog_msg("Hello1 Hello2 Hello3 Hello4 Hello5 Hello6 World1 World2 World3 World4 World5 World6 World7 World8 Hello7 Hello8 ^_^ NyaNya! Naruto is rulezzz! Windows must die! I suck cocks! Emacs Vim FireFox Tetris Tomato 12345 :( :) -_- ABCDEFG QWERTY UIOP ASDF", dialog_reimu, dialog_normal);
    //dialog_msg("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! x", dialog_reimu, dialog_normal);

    bonus_power_create(50, -50);

    background_set_type(background_forest);

    @<Main cycle@>
}
@}

Основной циклы игры:

@d Main cycle @{
while(1) {
    @<Update timers@>
    @<Skip frames@>
    @<FPS@>

    @<Main cycle actions@>

    @<Get processor time to OS@>
    /*{//FIXME
        static int c = 0;

        if(c == 0) {
            dialog_left_add(dialog_yukari);
            dialog_left_add(dialog_reimu);
            dialog_right_add(dialog_marisa);
            c++;
        } else if (c == 1 && dialog_says == 0) {
            dialog_msg("Hello1 Hello2 Hello3", dialog_reimu, dialog_normal);
            c++;
        } else if (c == 2 && dialog_says == 0) {
            dialog_msg("Angry angry angry angry", dialog_reimu, dialog_angry);
            c++;
        } else if (c == 3 && dialog_says == 0) {
            dialog_msg("1345 1234 1234", dialog_yukari, dialog_normal);
            c++;
        } else if (c == 4 && dialog_says == 0) {
            dialog_msg("marisa marisa marisa", dialog_marisa, dialog_normal);
            c = 1;
        }
    }
    dialog_end();*///FIXME
}
@}

Мы держим fps~60.
FIXME: 60 мало, бекграунд дёргается. Надо хотя бы 80.
Добавим таймер для контроля перерисовки экрана раз в 1000/60 мс:
@d Skip frames @{
static int frames = 0;
static int main_timer_frame = 0;

main_timer_frame = timer_calc(main_timer_frame);
if(main_timer_frame == 0) {

    main_timer_frame = 1000/45;

    frames++;

    @<Draw backgrounds@>
    @<Draw bonuses@>
    @<Draw bullets@>
    @<Draw characters@>
    @<Draw player@>
    @<Draw dialog@>
    @<Draw panel@>
    @<Draw FPS@>
    @<Window update@>
}
@}
frames - необходим для подсчета FPS описаного ниже.

Засекаем время и делаем столько циклов обновления time points персонажей и вызовов
их ai, сколько мс. прошло:
@d Main cycle actions @{
@<Timer for time points@>
int i;
for(i=0; i<(1000 - main_timer_time_points)*2; i++) {
    @<Time points@>
    @<Computer movements@>
    @<Bullet movements@>
    @<Player movements@>
    @<Player press fire button@>
    @<Player press shadow button@>
    @<Player press next dialog button@>
    @<Bonus movements@>
    @<Dialog movements@>
    @<Damage calculate@>
    @<Get bonuses@>
    @<Game menu@>
}
@<Update time points@>
@}

@d Timer for time points @{
static int main_timer_time_points = 1000;
main_timer_time_points = timer_calc(main_timer_time_points);
@}

Обновим таймер:
@d Update time points @{
main_timer_time_points = 1000;
@}

Пересчитаем time points для различных вещей:
@d Time points @{
characters_update_all_time_points();
player_update_all_time_points();
bullets_update_all_time_points();
bonuses_update_all_time_points();
dialog_update_all_time_points();
background_update_animation();
@}

Добавим таймер для FPS.
Считаем fps за 5 сек:
@d FPS @{
{
    static int main_timer_fps = 0;

    main_timer_fps = timer_calc(main_timer_fps);
    if(main_timer_fps == 0) {

        main_timer_fps = 5000;

        fps = frames / 5;
        printf("%d frames %d FPS\n", frames, fps);

        frames = 0;
    }
}
@}

@d main variables
@{int fps = 0;
@}

Рисуем задник:
@d Draw backgrounds
@{background_draw();
@}

Отрисовка всех персонажей:
@d Draw characters
@{characters_draw();
@}

Отрисовка главного персонажа:
@d Draw player
@{player_draw();
@}

Отрисовка пуль:
@d Draw bullets
@{bullets_draw();
@}

Отрисовка бонусов:
@d Draw bonuses
@{bonuses_draw();
@}

Панель со статистикой:
@d Draw panel
@{panel_draw();
@}

Рисуем окно диалога:
@d Draw dialog
@{dialog_draw();
@}

@d Draw FPS
@{{
    static int fd = -1;
    char buf[10];

    if(fd == -1)
        fd = load_font("big_font1.txt");

    sprintf(buf, "%dfps", fps);
    print_text(buf, GAME_FPS_X, GAME_FPS_Y, 90, color_white, fd);
}
@}

Обновление экрана:
@d Window update @{
window_update();@}

Игровое меню(оно вызывается из игры при нажатии ESC):
@d Game menu @{
if(is_keydown(key_escape)) {
    window_set_fullscreen(0);
    exit(1);
}
@}
FIXME:Пока вместо меню заглушка


Перемещение персонажа игроком:
@d Player movements @{
if(is_keydown(key_move_left))
    player_move_to(player_move_to_left);
else if(is_keydown(key_move_right))
    player_move_to(player_move_to_right);

if(is_keydown(key_move_up))
    player_move_to(player_move_to_up);
else if(is_keydown(key_move_down))
    player_move_to(player_move_to_down);
@}
Кнопки влево, вправо и вверх, вниз разделены, чтобы была возможность перемещаться по диагонали.

Игрок нажал кнопку "огонь":
@d Player press fire button @{
if(is_keydown(key_fire)) {
    player_fire();
}
@}

Игрок переключился на теневую форму:
@d Player press shadow button @{
if(is_keydown(key_shadow_character))
    player_shadow_character();
else
    player_human_character();
@}

Перелистывать страницы в диалогах нажатием кнопки:
@d Player press next dialog button @{
if(is_keydown(key_next_dialog)) {
    dialog_next_page();
}
@}

Перемещение персонажей управляемых компьютером:
@d Computer movements @{
characters_ai_control();
@}

Перемещение пуль:
@d Bullet movements @{
bullets_action();
@}

Перемещение бонусов:
@d Bonus movements @{
bonuses_action();
@}

Изменения в окне диалогов:
@d Dialog movements @{
dialog_action();
@}

Обновим таймеры:
@d Update timers @{
timer_get_time();
@}

Подсчитаем повреждения от пуль:
@d Damage calculate @{
damage_calculate();
@}

Собираем бонусы:
@d Get bonuses @{
player_bonus_line();
@}
player_bonus_line - проверяем бонусную линию.

Отдадим процессору немного времени:
@d Get processor time to OS @{
get_processor_time();
@}
FIXME: что-то на nvidia он жутко просаживает систему


@d License
@{/*
 * danmaku
 * Copyright (C) 2010-2012 Iljasov Ramil
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
@}
