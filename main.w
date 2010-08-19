

2010 28 июля
начинаю писать концепт даммаку



1)стараюсь делать по KISS
2)делаю тяпляп, лишь бы работало
3)я делаю Touhou, а не универсальный двиг


==========================================================

Игровые константы.


@o const.h @{
#ifndef _CONST_H_
#define _CONST_H_

@<const.h game field width and height@>
@<const.h game field coodinate@>

#endif
@}


Размер игрового поля, где происходит действие игры:
@d const.h game field width and height @{
#define GAME_FIELD_W 380
#define GAME_FIELD_H 580
@}
Использовать в алгоритмах. Начало в точке (0, 0).


Левый верхний угол игрового поля, где происходит действие игры:
@d const.h game field coodinate @{
#define GAME_FIELD_X 10
#define GAME_FIELD_Y 10
@}
Лучше помещать эти константы в функции вырисовки, а не в алгоритмы.

===========================================================

Набор функция для работы с окном(создание, рисование...).



Структура файла функций зависимых от ОС:
@o os_specific.c @{
#include <SDL.h>
#include <SDL_image.h>

#include <GL/gl.h>
#include <GL/glu.h>

#include <stdlib.h>

#include "os_specific.h"

static SDL_Surface *surface;

@<os_specific structs@>
@<os_specific private prototypes@>
@<os_specific functions@>
@}

@o os_specific.h @{
@<os_specific public prototypes@>
@}


Эту функцию вызывают один раз, когда программа запускается(в начале функции main):
@d os_specific functions @{
void window_init(void) {
	if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_TIMER) != 0) {
		fprintf(stderr, "\nUnable to initialize SDL:  %s\n",
				SDL_GetError());
		exit(1);
	}

	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
}
@}

@d os_specific public prototypes @{
void window_init(void);
@}




Нам нужна функция, которая создаёт окно(window_create). Её также нужно вызывать после изменения
характеристик окна.
Изменение характеристик приводит к изменению настроек OGL, следовательно OGL стоит
настраивать в этой функции.




@d os_specific functions @{
static int w = 800, h = 600, fullscreen;
static int game_w = 800, game_h = 600;
static Uint32 flags = SDL_OPENGL;

void window_create(void) {

	flags = fullscreen ? flags | SDL_FULLSCREEN : flags & ~SDL_FULLSCREEN;

	surface = SDL_SetVideoMode(w, h, 16, flags);
	if(surface == NULL) {
		fprintf(stderr, "Unable to set 640x480 video: %s\n", SDL_GetError());
		exit(1);
	}

	@<os_specific OGL config@>

	return;
}
@}
w, h - размеры окна
game_w, game_h - размеры окна в игре, они будут растягиваться под w, h

@d os_specific public prototypes @{
void window_create(void);
@}


Настройки OGL для вывода 2D графики:
@d os_specific OGL config @{
glClearColor(0, 0, 0, 0);
glClear(GL_COLOR_BUFFER_BIT);

glEnable(GL_TEXTURE_2D);

@<os_specific OGL blend@>

glViewport(0, 0, w, h);

glMatrixMode(GL_PROJECTION);
glLoadIdentity();

glOrtho(0, game_w, game_h, 0, 0, 1);

glDisable(GL_DEPTH_TEST);

glMatrixMode(GL_MODELVIEW);
glLoadIdentity();
@}


Нам нужна поддержка прозрачности для вывода спрайтов с alpha каналом:
@d os_specific OGL blend @{
glEnable(GL_BLEND);
glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
@}



Функция изменения размера окна:
@d os_specific functions @{
void window_set_size(int w_, int h_) {
	w = w_;
	h = h_;

	window_create();
}
@}
Как видно window_create она запускает сама. Может кому-то и не нравятся мелькающие окна, а мне
пофиг.

@d os_specific public prototypes @{
void window_set_size(int w_, int h_);
@}



Очень простые функции для работы с fullscreen:
@d os_specific functions @{
void window_set_fullscreen(int flag) {
	fullscreen = flag;

	window_create();
}

int window_is_fullscreen(void) {
	return fullscreen;
}
@}

@d os_specific public prototypes @{
void window_set_fullscreen(int flag);
int window_is_fullscreen(void);
@}



Эту фунцию вызывают когда уже все нарисовано в буфере:
@d os_specific functions @{
void window_update(void) {
	SDL_GL_SwapBuffers();
}
@}

@d os_specific public prototypes @{
void window_update(void);
@}




Перейдём к функциям по работе с изображениями.

image_load будет кроме возвращения дескриптора ещё сохранять имя файла для защиты от
двойной загрузки файла(FIXME:надо реализовать).

Так как нам придётся проверять все рисунки, то мы будем их хранить в массиве.
Для начала, почему массив? Этот массив похож на стек. Список рисунков всё равно не
имеет дыр, поэтому будем использовать этот достаточно простой вариант.
id который возвращает image_load и есть номер элемента в массиве.

Опишем структуру в которой будет храниться список открытых изображений:
@d os_specific structs @{
#define IMAGE_LIST_LEN 1024
#define IMG_FILE_NAME_SIZE 30

typedef struct {
	char filename[IMG_FILE_NAME_SIZE];
	int w, h;
	unsigned int tex_id;
} ImageList;

static ImageList image_list[IMAGE_LIST_LEN];
static int image_list_pos;
@}
Это стек, image_list_pos его вершина.
IMG_FILE_NAME_SIZE длинна массива под имя файла включая и путь к файлу.
IMAGE_LIST_LEN количество изображений или иными словами размер стека.

filename - имя файла с картинкой
w, h - размеры картинки
tex_id - дескриптор текстуры в opengl



Функция загрузки изображения image_load:
@d os_specific functions @{
int image_load(char *filename) {
	if(image_list_pos == IMAGE_LIST_LEN) {
		fprintf(stderr, "\nImage list full\n");
		exit(1);
	}

	strncpy(image_list[image_list_pos].filename, filename,
			sizeof(image_list[image_list_pos].filename));

	{
		int bytes_per_pixel;
		int texture_format;

		ImageList *image = &image_list[image_list_pos];

		SDL_Surface *img = load_from_file(filename);

		@<os_specific image file size check@>
		@<os_specific set bytes_per_pixel and texture_format@>

		image->w = img->w;
		image->h = img->h;

		glGenTextures(1, &image->tex_id);

		glBindTexture(GL_TEXTURE_2D, image->tex_id);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		glTexImage2D(GL_TEXTURE_2D, 0, bytes_per_pixel, img->w, img->h, 0,
			texture_format, GL_UNSIGNED_BYTE, img->pixels);

		SDL_FreeSurface(img);
	}

	return image_list_pos++;
}
@}
Как видно есть контроль переполнения буфера, где хранится имя файла.
То есть в структуре-стеке всегда валидное имя.
Используется вспомогательная функция load_from_file, она загружает картинку по заданому пути.
Функция image_load возвращает позицию в стеке, она служит дескриптором изображения.

@d os_specific public prototypes @{
int image_load(char *filename);
@}


Размер должен быть кратен 2:
@d os_specific image file size check @{
if((img->w & (img->w - 1)) != 0 ||
	(img->h & (img->h - 1)) != 0) {
	fprintf(stderr, "\nImage size isn't power of 2: %s\n", filename);
	exit(1);
}
@}

Получить количество байтов на пиксел и формат изображения:
@d os_specific set bytes_per_pixel and texture_format @{
bytes_per_pixel = img->format->BytesPerPixel;

switch(bytes_per_pixel) {
	case 4:
		if(img->format->Rmask == 0x000000ff)
			texture_format = GL_RGBA;
		else
			texture_format = GL_BGRA;
		break;
	case 3:
		if(img->format->Rmask == 0x000000ff)
			texture_format = GL_RGB;
		else
			texture_format = GL_BGR;
		break;
	default:
		fprintf(stderr, "\nIncorect color type: %s\n", filename);
		exit(1);
}
@}
Допустимо только 4 или 3 байта на пиксел.



Теперь о вспомогательной функции подробнее:
@d os_specific functions @{
static SDL_Surface *load_from_file(char *filename) {
	SDL_Surface *img;
	char dirname[] = "images/";
	char buf[IMG_FILE_NAME_SIZE + sizeof(dirname) + 1];

	strcpy(buf, dirname);
	strcat(buf, filename);

	img = IMG_Load(buf);
	if(img == 0) {
		fprintf(stderr, "IMG_Load: %s\n", IMG_GetError());
		exit(1);
	}
}
@}
У функция подсчитывает количество символов в имени директории и создаёт подходящий массив.
Она не проверяет есть ли '.' в пути к файлу, это потенциальная уязвимость, но пока это меня
не беспокоит :3

@d os_specific private prototypes @{
static SDL_Surface *load_from_file(char *filename);
@}




Функция вывода изображения с левого-верхнего края:
@d os_specific functions @{
void image_draw_corner(int id, int x, int y, float rot, float scale) {
	ImageList *img = &image_list[id];

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	glBegin(GL_QUADS);
		glTexCoord2i(0, 0);
		glVertex2i(0, 0);

		glTexCoord2i(1, 0);
		glVertex2i(img->w, 0);

		glTexCoord2i(1, 1);
		glVertex2i(img->w, img->h);


		glTexCoord2i(0, 1);
		glVertex2i(0, img->h);
	glEnd();
}
@}

@d os_specific public prototypes @{
void image_draw_corner(int id, int x, int y, float rot, float scale);
@}



Функция вывода изображения с центра:
@d os_specific functions @{
void image_draw_center(int id, int x, int y, float rot, float scale) {
	ImageList *img = &image_list[id];

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	glBegin(GL_QUADS);
		glTexCoord2i(0, 0);
		glVertex2i(-img->w/2, -img->h/2);

		glTexCoord2i(1, 0);
		glVertex2i(img->w/2, -img->h/2);

		glTexCoord2i(1, 1);
		glVertex2i(img->w/2, img->h/2);

		glTexCoord2i(0, 1);
		glVertex2i(-img->w/2, img->h/2);
	glEnd();
}
@}

@d os_specific public prototypes @{
void image_draw_center(int id, int x, int y, float rot, float scale);
@}




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

@<keys' events for is_keydown@>
@<is_keydown function prototype@>

@}

Придумаем события:

@d keys' events for is_keydown @{

enum {
	key_fire, key_move_left, key_move_right, key_move_up, key_move_down,
	key_menu_up, key_menu_down, key_menu_select, key_escape
};

@}

Интересно, есть устройства где для перемещению по меню используются другие кнопки? Пусть будут.

@d is_keydown function prototype @{
int is_keydown(int key_type);
@}

Реализация is_keydown:

@o event.c @{
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
static int fire, move_left, move_right, move_up, move_down, escape;
@}

Здесь мы устанавливаем и сбрасываем флаги:

@d Get event @{
while(SDL_PollEvent(&event)) {
	int key = event.type == SDL_KEYDOWN;

	switch(event.key.keysym.sym) {
		case SDLK_SPACE:
			fire = key;
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
	default:
		fprintf(stderr, "\nUnknown key\n");
		exit(1);
}
@}


======================================================

Простой набор функций контроля пересечения прямоугольников:

@o collision.h @{
typedef struct {
	int l, r, t, b;
} Rect;

int is_collide(const Rect *a, const Rect *b);
@}

Реализация:

@o collision.c @{
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

Теперь стоит подумать о игровых персонажах.
Они должны иметь возможность свободно перемещаться по игровому полю и исчезать когда им захочется.
Для этого они должны знать размер окна, через которое игрок видит игровое поле. Допустим его размеры
константа и описываются в каком-нибудь файле.

-Должны ли пули и снаряды хранится с игровыми персонажами в одном списке?
Пули не возвращают дескрипторы(их слишком много). Этим они отличаются от персонажей.

Пули будут иметь специальную функцию, которая принимает прямоугольник у персонажа и сообщает было пересечение
или нет.
Возможен и обратный подход, когда персонаж имеет функцию, а пуля прямоугольник пересечения, но в таком
случае мы не сможем отображать снизу области поражения вражеских персонажей.
Функция перемещения, её вызов двигает снаряд на итерацию.



Фунции для перемещения персонажей:
@o characters.h @{
enum {
	character_move_to_left, character_move_to_right, character_move_to_up, character_move_to_down
};

void character_move_to(int cd, int move_to);
void characters_update_all_time_points(void);
void characters_ai_control(void);
@}

С первой функцией всё понятно. characters_update_all_time_points нужно вызывать в конце
каждого опроса перемещений ВСЕХ персонажей. Она восстанавливает очки перемещения у
всех персонажей, те после определённого количества вызовов этой функции,
персонажы смогут сделать один ход.
characters_ai_control - сделать ход всеми персонажами, которые не спят, у которых ai - истина.

Рисуем:
@o characters.h @{
void characters_draw(void);
@}


Опишем структуру персонажа:
@o characters.h @{
#define CHARACTER_LIST_LEN 2040

typedef struct {
	int hp;
	int x;
	int y;
	int ai;
	int is_sleep;
	int character_type;
	int time_point_for_movement_to_x;
	int time_point_for_movement_to_y;
	@<Character struct param@>
} CharacterList;

extern CharacterList characters[CHARACTER_LIST_LEN];
extern int characters_pos;
@}

CHARACTER_LIST_LEN максимальный размер стека с игровыми персонажами.
characters_pos вершина стека

О структуре:
  hp - количество жизней персонажа
  x, y - координаты, когда он не спит
  ai - флаг, этот персонаж управляется компьютером(существует только один не спящий(is_sleep=0) с ai=0)
  is_sleep - флаг, спит персонаж или действует на поле игр. Если персонаж умер,
  		   	 то флаг устанавливается(true).
  character_type - тип персонажа, основной параметр для диспетчеризации
  time_point_for_movement_to_x - может или нет персонаж переместиться по координате x,
  							   	 если этот параметр равен 0, то может. Этот параметр
								 уменьшается функцией characters_update_all_time_points,
								 и увеличивается функцией перемещения по координате x
  time_point_for_movement_to_y - аналогично time_point_for_movement_to_x

@o characters.c @{
#include <stdio.h>
#include <stdlib.h>

#include "characters.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"
#include "bullets.h"
#include "timers.h"


CharacterList characters[CHARACTER_LIST_LEN];
int characters_pos;

@<Character structs@>
@}


Перейдем к реализации функций.


Функции создания персонажей.

Типы персонажей:
@o characters.h @{
enum {
	character_reimu, character_marisa, @<Character types@>
};
@}

Рейму:
@o characters.c @{
void character_reimu_create(int cd) {
	CharacterList *character = &characters[cd];

	character->hp = 100;
	character->is_sleep = 1;
	character->character_type = character_reimu;
	character->time_point_for_movement_to_x = 0;
	character->time_point_for_movement_to_y = 0;
	character->step_of_movement = 0;

	character->x = player_x;
	character->y = player_y;

	character->team = 0;
	character->radius = 10;
}
@}
player_coord_x, player_coord_y - глобальные координаты игрока.
team - комманда. 0 - игрок, 1 - противник.
radius - радиус хитбокса.

@o characters.h @{
void character_reimu_create(int cd);
@}

Мариса:
@o characters.c @{
void character_marisa_create(int cd) {
	CharacterList *character = &characters[cd];

	character->hp = 100;
	character->is_sleep = 1;
	character->character_type = character_marisa;
	character->time_point_for_movement_to_x = 0;
	character->time_point_for_movement_to_y = 0;
	character->step_of_movement = 0;

	character->x = player_x;
	character->y = player_y;

	character->team = 0;
	character->radius = 10;
}
@}

@o characters.h @{
void character_marisa_create(int cd);
@}



Функции перемещения и восстановления очков перемещения.

Опишем вначале функцию перемещения:
@o characters.c @{
@<Different characters set weak time_point functions@>
@<character_set_weak_time_point functions@>

void character_move_to(int cd, int move_to) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x == 0) {
		if(move_to == character_move_to_left) {
			character_set_weak_time_point_x(cd);
			character->x--;
		}
		else if(move_to == character_move_to_right) {
			character_set_weak_time_point_x(cd);
			character->x++;
		}

		if(character->ai == 0)
			player_x = character->x;
	}

	if(character->time_point_for_movement_to_y == 0) {
		if(move_to == character_move_to_up) {
			character_set_weak_time_point_y(cd);
			character->y--;
		}
		else if(move_to == character_move_to_down) {
			character_set_weak_time_point_y(cd);
			character->y++;
		}

		if(character->ai == 0)
			player_y = character->y;
	}
}
@}

В этой функции используются функции character_set_weak_time_point_x и
character_set_weak_time_point_y. Они определяют тип персонажа cd и
вызывают специализированию функцию для каждого типа персонажа. Она устанавливает
значение для time_point_for_movement_to_x и time_point_for_movement_to_y
после того как было сделано перемещение.

Как видно, ход по x или y возможен только если соответствующий time_point равен нулю.

player_coord_x и player_coord_y - глобальные координаты игрока. Они меняются, если перемещается
персонаж у которого ai = 0(персонаж не управляется компьютером).
Когда нам нужно будет менять персонажа при нажатии Shift мы установим у другого флаг is_sleep,
тогда не будет двух активных персонажей с ai = 0.

Опишем character_set_weak_time_point_x и character_set_weak_time_point_y:
@d character_set_weak_time_point functions @{
static void character_set_weak_time_point_x(int cd) {
	switch(characters[cd].character_type) {
		case character_reimu:
			character_reimu_set_weak_time_point_x(cd);
			break;
		case character_marisa:
			character_marisa_set_weak_time_point_x(cd);
			break;
		@<character_set_weak_time_point_x other characters@>
		default:
			fprintf(stderr, "\nUnknown character\n");
			exit(1);
	}
}

static void character_set_weak_time_point_y(int cd) {
	switch(characters[cd].character_type) {
		case character_reimu:
			character_reimu_set_weak_time_point_y(cd);
			break;
		case character_marisa:
			character_marisa_set_weak_time_point_y(cd);
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
static void character_reimu_set_weak_time_point_x(int cd) {
	characters[cd].time_point_for_movement_to_x = 5;
}

static void character_reimu_set_weak_time_point_y(int cd) {
	characters[cd].time_point_for_movement_to_y = 5;
}

static void character_marisa_set_weak_time_point_x(int cd) {
	characters[cd].time_point_for_movement_to_x = 10;
}

static void character_marisa_set_weak_time_point_y(int cd) {
	characters[cd].time_point_for_movement_to_y = 10;
}
@}



Функция которая восстанавливает время до следующего хода
у всех персонажей в игре:

@o characters.c @{
@<Update time point for different characters@>

void characters_update_all_time_points(void) {
	int i;

	for(i = 0; i < characters_pos; i++)
		switch(characters[i].character_type) {
			case character_reimu:
				character_reimu_update_time_points(i);
				break;
			case character_marisa:
				character_marisa_update_time_points(i);
				break;
			@<characters_update_all_time_points other characters@>
			default:
				fprintf(stderr, "\nUnknown character\n");
				exit(1);
		}
}
@}

Реализация обновления времени до следующего хода у конкретного вида
персонажей:

@d Update time point for different characters @{
static void character_reimu_update_time_points(int cd) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x > 0)
		character->time_point_for_movement_to_x--;

	if(character->time_point_for_movement_to_y > 0)
		character->time_point_for_movement_to_y--; 
}

static void character_marisa_update_time_points(int cd) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x > 0)
		character->time_point_for_movement_to_x--;

	if(character->time_point_for_movement_to_y > 0)
		character->time_point_for_movement_to_y--;
}
@}



Сделаем ход всеми компьютерными персонажами. Персонажи которые спят,
мертвы и которыми не управляет компьютер(ai = false) пропускают ход.

@o characters.c @{
@<Helper functions@>
@<AI functions for different characters@>

void characters_ai_control(void) {
	int i;

	for(i = 0; i < characters_pos; i++) {
		CharacterList *character = &characters[i];

		if(character->ai == 0 || character->hp <= 0 || character->is_sleep == 1)
			continue;

		switch(character->character_type) {
			case character_reimu:
				character_reimu_ai_control(i);
				break;
			case character_marisa:
				character_marisa_ai_control(i);
				break;
			@<characters_ai_control other characters@>
			default:
				fprintf(stderr, "\nUnknown character\n");
				exit(1);
		}
	}
}
@}

Мозги для конкретных персонажей:
@d AI functions for different characters @{
static void character_reimu_ai_control(int cd) {
	CharacterList *character = &characters[cd];

	@<Reimu ai control@>
}

static void character_marisa_ai_control(int cd) {
	exit(1); // FIXME
}
@}


==============================================================

Вспомогательные функции.

character_move_to_point - движение к точке.
Каждый её вызов передвигает персонаж cd ближе к точке (x,y)

@d Helper functions @{
static void character_move_to_point(int cd, int x, int y) {
	CharacterList *character = &characters[cd];

	@<character_move_to_point params@>
	@<character_move_to_point is end of movement?@>
	@<character_move_to_point save start coordinate@>
	@<character_move_to_point calculate percent of movement@>
	@<character_move_to_point choose direction@>
}
@}

Проверим достигли мы конечной точки или нет:
@d character_move_to_point is end of movement? @{
if(character->x == x && character->y == y) {
	character->move_percent = 0;
	return;
}
@}
Мы не забыли установить процент движения move_percent в 0. Движения больше нет.


Если мы только начали движение, то нужно запомнить начальные координаты
движения:
@d character_move_to_point save start coordinate @{
if(character->move_percent == 0) {
	character->move_begin_x = character->x;
	character->move_begin_y = character->y;
}
@}
Можно считать, что move_percent = 100.

Посчитаем какой процент расстояния осталось пройти. Для этого поделим расстояние
до конечной точки на длину всего маршрута:
@d character_move_to_point calculate percent of movement @{
{
	int dx, dy;
	float all, last;

	dx = character->move_begin_x - x;
	dy = character->move_begin_y - y;
	@<character_move_to_point find correction coef@>

	all = sqrt(dx*dx + dy*dy);

	dx = character->x - x;
	dy = character->y - y;
	@<character_move_to_point correction coef at this time@>

	last = sqrt(dx*dx + dy*dy);

	character->move_percent = (int)((last/all) * 100.0);
}
@}
Поиски correction coef не относятся к этой задаче, зачем они написано ниже.
FIXME: возможно стоит перенести поиск процента оставшегося растояния в отдельную функцию,
а атрибут move_percent убрать. (+) освободим память, (-) чаще будем пересчитывать move_percent.

Добавим к структуре новые параметры:
@d Character struct param @{
int move_percent;
int move_begin_x;
int move_begin_y;
@}
move_percent - процент пути который осталось пройти. В конце пути он равен 0.
Для того чтобы сбросить старое движение и начать новое, нужно присвоить move_percent 0.
move_begin_x, move_begin_y - начальные координаты движения.


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
		character_move_to(cd, character_move_to_left);
	else
		character_move_to(cd, character_move_to_right);
}

if(fy == 1 && character->y != y) {
	if(character->y > y)
		character_move_to(cd, character_move_to_up);
	else
		character_move_to(cd, character_move_to_down);
}
@}

@d character_move_to_point params @{
int fx = 0, fy = 0;
@}


===========================================================


Опишем поведение боссов.
Пусть оно пока храниться здесь, позже перенесу.

Нам понадобиться специальный параметр, который показывает какое
дествие совершается.

@d Character struct param @{
int step_of_movement;
@}

Добавим такую строку в функцию create всем персонажам:
character->step_of_movement = 0;


Босс движется из точки в точку. Достигает её. Мы изменяем step_of_movement,
чтобы знать какой шаг делать потом.

@d Character structs @{
typedef struct {
	int x, y;
} Point;
@}

@d Reimu ai control @{
Point p[] = {{100, 100}, {200, 10}, {10, 200}, {200, 200}, {10, 10}};

if(character->step_of_movement == 5)
	character->step_of_movement = 0;

character_move_to_point(cd, p[character->step_of_movement].x, p[character->step_of_movement].y);

if(character->move_percent == 0) {
	character->step_of_movement++;
}
@}

Перемещаемся между точками.


В будущем нам могут понадобиться две переменные:
@d Character struct param @{
int move_x;
int move_y;
@}
Они требуются, когда нужно где-то сохранить точку куда двигается персонаж.
Используются в ai.

Иногда нужно ждать некоторое время, таймер можно хранить здесь:
@d Character struct param @{
int time;
@}

===========================================================

Функция которая рисует всех персонажей, которые не спят.
Стоит рисовать её до того как нарисовать рамку, чтобы рамка перекрыла
не полностью вылезших персонажей.
FIXME: Пока рисует всех, а не только не спящих.

@o characters.c @{
@<Draw functions for different characters@>

void characters_draw(void) {
	int i;

	for(i = 0; i < characters_pos; i++)
		switch(characters[i].character_type) {
			case character_reimu:
				character_reimu_draw(i);
				break;
			case character_marisa:
				character_marisa_draw(i);
				break;
			@<characters_draw other characters@>
			default:
				fprintf(stderr, "\nUnknown character\n");
				exit(1);
		}
}
@}

Конкретные функции рисования для различных персонажей:

@d Draw functions for different characters @{
static void character_reimu_draw(int cd) {
	CharacterList *character = &characters[cd];
	static int id = -1;

	if(id == -1)
		id = image_load("aya.png");

	if(character->is_sleep == 1)
		return;

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.1);
}

static void character_marisa_draw(int cd) {
	CharacterList *character = &characters[cd];
	static int id = -1;

	if(id == -1)
		id = image_load("marisa.png");

	if(character->is_sleep == 1)
		return;

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.1);
}
@}


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

Добавим в список:
@d Character types @{
character_blue_moon_fairy,
@}

Функция создания персонажа:
@o characters.c @{
void character_blue_moon_fairy_create(int cd, int x, int y) {
	CharacterList *character = &characters[cd];

	character->x = x;
	character->y = y;
	character->hp = 100;
	character->is_sleep = 1;
	character->character_type = character_blue_moon_fairy;
	character->time_point_for_movement_to_x = 0;
	character->time_point_for_movement_to_y = 0;
	character->step_of_movement = 0;
	character->team = 1;
	character->radius = 20;
}
@}
team = 1 - комманда противников.
radius - радиус хитбокса.

@o characters.h @{
void character_blue_moon_fairy_create(int cd, int x, int y);
@}

Функции установки time points после совершения перемещения:
@d character_set_weak_time_point_x other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_set_weak_time_point_x(cd);
	break;
@}

@d character_set_weak_time_point_y other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_set_weak_time_point_y(cd);
	break;
@}

@d Different characters set weak time_point functions @{
static void character_blue_moon_fairy_set_weak_time_point_x(int cd) {
	characters[cd].time_point_for_movement_to_x = 5;
}

static void character_blue_moon_fairy_set_weak_time_point_y(int cd) {
	characters[cd].time_point_for_movement_to_y = 5;
}
@}

Функции обновления time points:
@d characters_update_all_time_points other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_update_time_points(i);
	break;
@}

@d Update time point for different characters @{
static void character_blue_moon_fairy_update_time_points(int cd) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x > 0)
		character->time_point_for_movement_to_x--;

	if(character->time_point_for_movement_to_y > 0)
		character->time_point_for_movement_to_y--; 
}
@}

AI феи:
@d characters_ai_control other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_ai_control(i);
	break;
@}

@d AI functions for different characters @{
static void character_blue_moon_fairy_ai_control(int cd) {
	CharacterList *character = &characters[cd];
	@<character_blue_moon_fairy_ai_control move to down and center@>
	@<character_blue_moon_fairy_ai_control wait@>
	@<character_blue_moon_fairy_ai_control go away@>
	@<character_blue_moon_fairy_ai_control move and remove@>
}
@}

Перемещаемся поближе к центру(чуть выше) игрового поля. Чем персонаж ближе к центру в
начальный момент, тем ближе он подлетит в конце.
Для начала пройдём полмаршрута и выстрелим:
@d character_blue_moon_fairy_ai_control move to down and center @{
if(character->step_of_movement == 0) {
	character->move_x = GAME_FIELD_W/2 + (character->x - GAME_FIELD_W/2)/2;
	character->move_y = GAME_FIELD_H/2 - GAME_FIELD_H/4 + character->y;
	character->step_of_movement = 1;
}

if(character->step_of_movement == 1) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->move_percent < 50) {
		bullet_white_spray3_create(character->x, character->y);
		character->step_of_movement = 2;
	}
}
@}

Потом пройдем остаток маршрута и выстрелим:
@d character_blue_moon_fairy_ai_control move to down and center @{
if(character->step_of_movement == 2) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->move_percent == 0) {
		bullet_white_spray3_create(character->x, character->y);

		character->time = 500;
		character->step_of_movement = 3;
	}
}
@}

Ждем полсекунды(character->time выше):
@d character_blue_moon_fairy_ai_control wait @{
if(character->step_of_movement == 3) {
	character->time = timer_calc(character->time);
	if(character->time == 0)
		character->step_of_movement = 4;
}
@}

Улетаем за край экрана. Те что слева от центра улетают направо, те что
справа от центра налево:
@d character_blue_moon_fairy_ai_control go away @{
if(character->step_of_movement == 4) {
	character->move_x = character->x < GAME_FIELD_W/2 ? GAME_FIELD_W + 30 : -30;
	character->move_y = character->y - GAME_FIELD_H/5;
	character->step_of_movement = 5;
}
@}

Перемещаемся в (move_x, move_y). Стреляем на половине пути:
@d character_blue_moon_fairy_ai_control move and remove @{
if(character->step_of_movement == 5) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->move_percent < 50) {
		bullet_white_spray3_create(character->x, character->y);
		character->step_of_movement = 6;
	}
}
@}

Перемещаемся остаток пути. Убираем тех, кто достиг края экрана:
@d character_blue_moon_fairy_ai_control move and remove @{
if(character->step_of_movement == 6) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->x > GAME_FIELD_W+20 || character->y < -20) {
		character->is_sleep = 1;
		character->step_of_movement = 0;
		character->move_percent = 0;
	}
}
@}
Очищаем step_of_movement и move_percent.


Рисуем персонажа:
@d characters_draw other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_draw(i);
	break;
@}

@d Draw functions for different characters @{
static void character_blue_moon_fairy_draw(int cd) {
	CharacterList *character = &characters[cd];
	static int id = -1;

	if(id == -1)
		id = image_load("blue_fairy.png");

	if(character->is_sleep == 1)
		return;

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.4);
}
@}
===========================================================

Игровой персонаж.

@o player.h @{
@<Player public structs@>
@<Player public prototypes@>
@}

@o player.c @{
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
}
@}
Используем свойство, что первый персонаж в команде имеет номер *2 от номера команды.

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
}

void player_human_character(void) {
	if(player_type % 2 == 1)
		player_type--;
}
@}
С помощью этих функции выбирается человек или ёкай.

Функция выстрела:
@d Player public prototypes @{
void player_fire(void);
@}

@d Player functions @{
void player_fire(void) {
	switch(player_type) {
		case player_reimu:
			//bullet_player_reimu_first_create();
			break;
		@<player_fire other players' fires@>
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
}
@}

@d Player private macros @{
#include "bullets.h"
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
			player_time_point_for_movement_to_x = 5;
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
			player_time_point_for_movement_to_y = 5;
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

Перечислим направления перемещения:
@d Player public structs @{
enum {
	player_move_to_left, player_move_to_right, player_move_to_up, player_move_to_down
};
@}

Функция которая уменьшает time points, что в итоге приводит к тому, что
персонаж может сдвинуться на позицию:
@d Player public prototypes @{
void player_update_all_time_points(void);
@}

@d Player functions @{
void player_update_all_time_points(void) {
	if(player_time_point_for_movement_to_x > 0)
		player_time_point_for_movement_to_x--;

	if(player_time_point_for_movement_to_y > 0)
		player_time_point_for_movement_to_y--; 
}
@}

Рисуем персонажей:
@d Player public prototypes @{
void player_draw(void);
@}

@d Player functions @{
void player_draw(void) {
	switch(player_type) {
		case player_reimu: {
			static int id = -1;

			if(id == -1)
				id = image_load("aya.png");

			image_draw_center(id,
				GAME_FIELD_X + player_x,
				GAME_FIELD_Y + player_y,
				0, 0.1);
			
			break;
		}
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
}
@}

@d Player private macros @{
#include "os_specific.h"
#include "const.h"
@}

===========================================================

Пули.

@o bullets.h @{
@<Bullet types@>
@<Bullet public macros@>
@<Bullet public structs@>
@<Bullet public prototypes@>
@}

@o bullets.c @{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "bullets.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"

@<Bullet private macros@>
@<Bullet private structs@>
@<Bullet private prototypes@>
@<Bullet functions@>
@}

Структура для хранения пуль:

@d Bullet public structs @{
typedef struct {
	int x;
	int y;
	float angle;
	int bullet_type;
	int is_noempty;
	@<Bullet params@>
} BulletList;
@}

x, y - коодинаты пули
angle - угол поворота
bullet_type - тип
is_noempty - не пустая ячейка для пули. Если флаг установлен, то эта ячейка занята.

Массив пуль:
@d Bullet public structs @{
extern BulletList bullets[BULLET_LIST_LEN];
@}

@d Bullet private structs @{
BulletList bullets[BULLET_LIST_LEN];
@}

BULLET_LIST_LEN - максимальное количество пуль

@d Bullet public macros @{
#define BULLET_LIST_LEN 2048
@}


Типы пуль:
@d Bullet private structs @{
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
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++)
		if(bullets[i].is_noempty == 0) {
			bullets[i].is_noempty = 1;
			return &bullets[i];
		}

	fprintf(stderr, "\nBullet list is full\n");
	exit(1);
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
	bullet->angle = shift_angle;
	bullet->bullet_type = bullet_red;
	bullet->move_flag = 0;

	bullet->team = 1;
}
@}
Пуля летит в сторону главного игрового персонажа.
Параметр shift_angle используется для задания отклонения пули от
игрового персонажа. Позже параметр angle начинает использоваться
как обычный угол для пули.
Параметр team обозначает комманду к которой принадлежит пуля. Единица
значит, что это команда противников и пуля напралена против игрока.


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
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++) {
		BulletList *bullet = &bullets[i];

		@<Skip cycle if bullet slot empty@>

		switch(bullet->bullet_type) {
			case bullet_white:
				bullet_white_action(i);
				break;
			case bullet_red:
				bullet_red_action(i);
				break;
			@<bullets_action other bullets@>
			default:
				fprintf(stderr, "\nUnknown bullet\n");
				exit(1);
		}
	}
}
@}

Пропустим один цикл for, если ячейка для пули пуста:
@d Skip cycle if bullet slot empty @{
if(bullet->is_noempty == 0)
	continue;
@}



Конкретые функции действия пуль.

Белая пуля делает круги:
@d Bullet actions @{
static void bullet_white_action(int bd) {
	BulletList *bullet = &bullets[bd];

	bullet_move_to_angle_and_radius(bd, bullet->angle, 10.0);

	if(bullet->move_flag == 0)
		bullet->angle += 5;
}
@}



Красная пуля улетает за край экрана по прямой.

Вычислим угол до персонажа, если пуля не перемещается и передадим в функцию
перемещения:
@d Bullet actions @{
static void bullet_red_action(int bd) {
	BulletList *bullet = &bullets[bd];

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
bullet_move_to_angle_and_radius(bd, bullet->angle,
	GAME_FIELD_W * GAME_FIELD_H);
@}
Теперь пуля гарантировано улетит за край экрана.

bullet_move_to_angle_and_radius - переместить пулю по направлению angel на радиус W*H. Когда
пуля достигнет цели, то move_flag сбросится в 0.

Уничтожем пулю когда она вылетит за пределы экрана:
@d bullet_red_action destroy bullet @{
if(bullet->x < -5 || bullet->x > GAME_FIELD_W + 5 ||
	bullet->y < -5 || bullet->y > GAME_FIELD_H + 5)
	bullet->is_noempty = 0;
@}



Сложные пули делаются так: мы создаем "главную" пулю, которая создаёт дочерние.
Дочерние пули имеют номер дескриптора родителя. Родитель меняет у дочерних пуль параметр
step_of_movement и тем самым меняет их поведение. Родитель должен находится
раньше всех дочерних пуль, иначе замена местами двух пуль при удалении повредит его
дескриптор.
Не стоит забывать, что у пуль "нет" дескрипторов.


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
static void bullet_move_to_angle_and_radius(int bd, float angle, float radius) {
	BulletList *bullet = &bullets[bd];

	if(bullet->move_flag == 0) {
		const double deg2rad = M_PI/180.0;
		bullet->move_x = bullet->x + (int)(radius*cos(angle*deg2rad));
		bullet->move_y = bullet->y + (int)(radius*sin(angle*deg2rad));
	}

	bullet_move_to_point(bd, bullet->move_x, bullet->move_y);
}
@}

После того как пуля пройдёт расстояние radius по направлению angle, флаг move_flag сбросится
в 0. Во время движения он будет равен 1. Это можно использовать в скриптах.
radius*cos(angle*deg2rad) пришлось приводить к int так как он давал погрешность и пуля не летала
по кругу, а улетала за край экрана.

@d Bullet private prototypes @{
static void bullet_move_to_point(int bd, int x, int y);
@}

@d Bullet functions @{
static void bullet_move_to_point(int bd, int x, int y) {
	BulletList *bullet = &bullets[bd];

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
			bullet_move_to(bd, bullet_move_to_left);
		else
			bullet_move_to(bd, bullet_move_to_right);
	}

	if(fy == 1 && dy != 0) {
		if(dy > 0)
			bullet_move_to(bd, bullet_move_to_up);
		else
			bullet_move_to(bd, bullet_move_to_down);
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
static void bullet_move_to(int bd, int move_to);
@}

@d Bullet functions @{
static void bullet_move_to(int bd, int move_to) {
	BulletList *bullet = &bullets[bd];

	if(bullet->time_point_for_movement_to_x == 0) {
		if(move_to == bullet_move_to_left) {
			bullet_set_weak_time_point_x(bd);
			bullet->x--;
		}
		else if(move_to == bullet_move_to_right) {
			bullet_set_weak_time_point_x(bd);
			bullet->x++;
		}
	}

	if(bullet->time_point_for_movement_to_y == 0) {
		if(move_to == bullet_move_to_up) {
			bullet_set_weak_time_point_y(bd);
			bullet->y--;
		}
		else if(move_to == bullet_move_to_down) {
			bullet_set_weak_time_point_y(bd);
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
static void bullet_set_weak_time_point_x(int bd);
static void bullet_set_weak_time_point_y(int bd);
@}

@d Bullet functions @{
static void bullet_set_weak_time_point_x(int bd) {
	switch(bullets[bd].bullet_type) {
		case bullet_white:
			bullet_white_set_weak_time_point_x(bd);
			break;
		case bullet_red:
			bullet_red_set_weak_time_point_x(bd);
			break;
		default:
			fprintf(stderr, "\nUnknown bullex\n");
			exit(1);
	}
}

static void bullet_set_weak_time_point_y(int bd) {
	switch(bullets[bd].bullet_type) {
		case bullet_white:
			bullet_white_set_weak_time_point_y(bd);
			break;
		case bullet_red:
			bullet_red_set_weak_time_point_y(bd);
			break;
		default:
			fprintf(stderr, "\nUnknown bullet\n");
			exit(1);
	}
}
@}

Конкретные реализации функции восстановления очков времени для разных видов пуль:

@d Bullet private prototypes @{
static void bullet_white_set_weak_time_point_x(int bd);
static void bullet_white_set_weak_time_point_y(int bd);

static void bullet_red_set_weak_time_point_x(int bd);
static void bullet_red_set_weak_time_point_y(int bd);
@}

@d Bullet functions @{
static void bullet_white_set_weak_time_point_x(int bd) {
	bullets[bd].time_point_for_movement_to_x = 1;
}

static void bullet_white_set_weak_time_point_y(int bd) {
	bullets[bd].time_point_for_movement_to_y = 1;
}

static void bullet_red_set_weak_time_point_x(int bd) {
	bullets[bd].time_point_for_movement_to_x = 5;
}

static void bullet_red_set_weak_time_point_y(int bd) {
	bullets[bd].time_point_for_movement_to_y = 5;
}
@}

Функция восстановления time points:

@d Bullet public prototypes @{
void bullets_update_all_time_points(void);
@}

@d Bullet functions @{
@<Update time point for different bullets@>

void bullets_update_all_time_points(void) {
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++) {
		BulletList *bullet = &bullets[i];

		@<Skip cycle if bullet slot empty@>

		switch(bullet->bullet_type) {
			case bullet_white:
				bullet_white_update_time_points(i);
				break;
			case bullet_red:
				bullet_red_update_time_points(i);
				break;
			default:
				fprintf(stderr, "\nUnknown bullet\n");
				exit(1);
		}
	}
}
@}

Функции восстановления для конкретных пуль:

@d Update time point for different bullets @{
static void bullet_white_update_time_points(int bd) {
	BulletList *bullet = &bullets[bd];

	if(bullet->time_point_for_movement_to_x > 0)
		bullet->time_point_for_movement_to_x--;

	if(bullet->time_point_for_movement_to_y > 0)
		bullet->time_point_for_movement_to_y--; 
}

static void bullet_red_update_time_points(int bd) {
	BulletList *bullet = &bullets[bd];

	if(bullet->time_point_for_movement_to_x > 0)
		bullet->time_point_for_movement_to_x--;

	if(bullet->time_point_for_movement_to_y > 0)
		bullet->time_point_for_movement_to_y--; 
}
@}



Нарисуем пули:

@d Bullet public prototypes @{
void bullets_draw(void);
@}

@d Bullet functions @{
void bullets_draw(void) {
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++) {
		BulletList *bullet = &bullets[i];

		@<Skip cycle if bullet slot empty@>

		switch(bullet->bullet_type) {
			case bullet_white:
				bullet_white_draw(i);
				break;
			case bullet_red:
				bullet_red_draw(i);
				break;
			default:
				fprintf(stderr, "\nUnknown bullet\n");
				exit(1);
		}
	}
}
@}

Рисуем конкретные:

@d Bullet private prototypes @{
static void bullet_white_draw(int bd);
static void bullet_red_draw(int bd);
@}

@d Bullet functions @{
static void bullet_white_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_green.png");

	image_draw_center(id,
		GAME_FIELD_X + bullets[bd].x,
		GAME_FIELD_Y + bullets[bd].y,
		bullets[bd].angle+90, 0.3);
}

static void bullet_red_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_green.png");

	image_draw_center(id,
		GAME_FIELD_X + bullets[bd].x,
		GAME_FIELD_Y + bullets[bd].y,
		bullets[bd].angle+90, 0.3);
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

==========================================================

Повреждения от пуль.


Эту часть попробую написать топорным методом.
Есть функция которая ничего не принимает и не возвращает. Имеет прямой доступ к
списку пуль и персонажей. Сама функция вызывает только функции проверки пересечения
окружностей персонажей и пуль, вычитание жизней и проверку на имунитет к пулям
производит сама.

Так как она распухнет, то поместим её в отдельный модуль.

@o damage.h @{
void damage_calculate(void);
@}

@o damage.c @{
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

Нам нужен доступ к списку пуль и списку персонажей:
@d Damage header @{
#include "characters.h"
#include "bullets.h"
@}

Функция перебирает всех персонажей, перебирает все пули,
передаёт хитбоксы пурсонажей внутрь функции проверки пересечения пули,
фукнция пересечения возвращает истину или ложь, мы проверяем особые случаи повреждения и
отнимаем у персонажа сколько нужно жизней:
@d damage_calculate body @{
int i, j;

for(i = 0; i < characters_pos; i++) {
	CharacterList *character = &characters[i];

	if(character->is_sleep == 0)
		for(j = 0; j < BULLET_LIST_LEN; j++) {
			BulletList *bullet = &bullets[j];

			@<Skip cycle if bullet slot empty@>

			@<damage_calculate character hp=0 or is_sleep=1@>
			@<damage_calculate character and bullet team check@>
			@<damage_calculate collision check@>
			@<damage_calculate character's damage unique@>
		}

	@<damage_calculate if hp<0 then character died@>
}
@}

Проверяемый персонаж уже мертв или спит и не выводится на экран:
@d damage_calculate character hp=0 or is_sleep=1 @{
if(character->hp <= 0 || character->is_sleep == 1)
	continue;
@}

В одной команде пуля и персонаж?
@d damage_calculate character and bullet team check @{
if(bullet->team == character->team)
	continue;
@}

Проверка пересечения:
@d damage_calculate collision check @{
if(bullet_collide(j, character->x, character->y, character->radius) == 0)
	continue;
@}

Особенности повреждения различных персонажей:
@d damage_calculate character's damage unique @{
switch(character->character_type) {
	case character_reimu:
//		if(bullet->bullet_type == bullet_red)
			character->hp = 0;
		break;
	default:
		fprintf(stderr, "\nUnknown character\n");
		exit(1);
}
@}

Если у персонажа нет жизней, то отметить is_sleep:
@d damage_calculate if hp<0 then character died @{
if(character->hp <= 0) {
	character->hp = 0;
	character->is_sleep = 1;
}
@}
Флаг устанавливается для всех персонажей, у кого hp <= 0,
вне зависимости от того "умерли" ли они сейчас или давно.


Напишем функцию bullet_collide:
@d Bullet public prototypes @{
int bullet_collide(int bd, int x, int y, int radius);
@}
Принимает дискриптор пули, координаты хитбокса персонажа и радиус хитбокса.

@d Bullet functions @{
int bullet_collide(int bd, int x, int y, int radius) {
	BulletList *bullet = &bullets[bd];

	switch(bullet->bullet_type) {
		case bullet_white:
		case bullet_red:
			@<bullet_collide if bullet_red collide@>
		default:
			fprintf(stderr, "\nUnknown bullet\n");
			exit(1);
	}

	return 0;
}
@}

Проверим красную пулю на пересечение. Если его небыло то выходим из switch, позже
вызовется return 0. Иначе уничтожаем пулю и вовращаем 1.
@d bullet_collide if bullet_red collide @{
if(is_rad_collide(x, y, radius, bullet->x, bullet->y, 3) == 0)
	break;
bullet->is_noempty = 0;
return 1;
@}


Для доступа к is_rad_collide добавим хедер:
@d Bullet private macros @{
#include "collision.h"
@}

Добавим параметры team:
@d Bullet params @{
int team;
@}

@d Character struct param @{
int team;
@}
Если команда пули и персонажа совпадают, то пуля безвредна.
В данной версии touhou только две команды: 0 - игрок, 1 - противники.

Добавим радиус хитбокса для персонажей:
@d Character struct param @{
int radius;
@}

=========================================================

Игровые этажи.

@o levels.h @{
@<Levels prototypes@>
@}

@o levels.c @{
#include <stdio.h>
#include <stdlib.h>

#include "levels.h"

@<Levels macros@>
@<Levels structs@>
@<Levels functions@>
@}

Надо придумать удобный и главное простой скриптовый язык.

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

Таймеры.


@o timers.c @{
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


Основной файл игры:

@o main.c @{

#include <stdlib.h>

#include "os_specific.h"
#include "event.h"
#include "collision.h"
#include "characters.h"
#include "bullets.h"
#include "timers.h"
#include "damage.h"
#include "player.h"
#include "const.h"


@<Main functions@>
@}


Функция main:

@d Main functions @{

int main(void) {
	window_init();
	window_create();

	enum {
		main_character_player,
		main_character_blue_moon_fairy1,
		main_character_blue_moon_fairy10 = main_character_blue_moon_fairy1 + 9,
	};

	player_x = GAME_FIELD_W/2;
	player_y = GAME_FIELD_H - GAME_FIELD_H/8;

	//character_reimu_create(main_character_player);
	//characters[main_character_player].ai = 0;
	//characters[main_character_player].is_sleep = 0;
	player_select_team(player_team_reimu);

	{
		int i;
		for(i = main_character_blue_moon_fairy1; i <= main_character_blue_moon_fairy10; i++) {
			character_blue_moon_fairy_create(i, 30*i, 10);
			characters[i].ai = 1;
			characters[i].is_sleep = 0;
		}
		characters_pos = main_character_blue_moon_fairy10 + 1;

//		characters[main_character_blue_moon_fairy1].is_sleep = 0;
	}

/*	{
		int i, j;
		for(i=0; i<1; i++)
			for(j=0; j<2; j++)
				bullet_red_create(100+i*10, 100+j*10);
	}*/

	@<Main cycle@>
}
@}

Основной циклы игры:

@d Main cycle @{
while(1) {
	@<Update timers@>
	@<Skip frames@>
	@<FPS@>
	@<Time points@>
	@<Computer movements@>
	@<Bullet movements@>
	@<Player movements@>
	@<Player press fire button@>
	@<Damage calculate@>
	@<Game menu@>
}
@}

Мы держим fps~60.
Добавим таймер для контроля перерисовки экрана раз в 1000/60 мс:
@d Skip frames @{
static int frames = 0;
static int main_timer_frame = 0;

main_timer_frame = timer_calc(main_timer_frame);
if(main_timer_frame == 0) {

	main_timer_frame = 1000/60;

	frames++;

	@<Draw bullets@>
	@<Draw characters@>
	@<Draw player@>
	@<Draw panel@>
	@<Window update@>
}
@}
frames - необходим для подсчета FPS описаного ниже.


Пересчет очков перемещения(time point). Добавим таймер для обновления time points:
@d Time points @{
static int main_timer_time_points = 0;

main_timer_time_points = timer_calc(main_timer_time_points);
if(main_timer_time_points == 0) {

	main_timer_time_points = 1;

	characters_update_all_time_points();
	player_update_all_time_points();
	bullets_update_all_time_points();
}
@}
Функции characters_update_all_time_points, player_update_all_time_points
и bullets_update_all_time_points вызываются раз в ~1 мс.


Добавим таймер для FPS.
Считаем fps за 5 сек:
@d FPS @{
{
	static int main_timer_fps = 0;
	
	main_timer_fps = timer_calc(main_timer_fps);
	if(main_timer_fps == 0) {

		main_timer_fps = 5000;

		printf("%d frames  %d FPS\n", frames, frames/5);

		frames = 0;
	}
}
@}


Отрисовка всех персонажей:
@d Draw characters @{
characters_draw();
@}

Отрисовка главного персонажа:
@d Draw player @{
player_draw();
@}

Отрисовка пуль:
@d Draw bullets @{
bullets_draw();
@}

Обновление экрана:
@d Window update @{
window_update();
@}

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
if(is_keydown(key_fire))
	player_fire();
@}

Перемещение персонажей управляемых компьютером:
@d Computer movements @{
characters_ai_control();
@}

Перемещение пуль:
@d Bullet movements @{
bullets_action();
@}

Обновим таймеры:
@d Update timers @{
timer_get_time();
@}

Подсчитаем повреждения от пуль:
@d Damage calculate @{
damage_calculate();
@}