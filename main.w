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



Структура файла функций зависимых от ОС:
@o os_specific.c @{
@<License@>

#include <SDL.h>
#include <SDL_image.h>

#include <GL/gl.h>
//#include <GL/glu.h>

#include <stdlib.h>
#include <math.h>

#include "os_specific.h"

static SDL_Surface *surface;

@<os_specific structs@>
@<os_specific private prototypes@>
@<os_specific functions@>
@}

@o os_specific.h @{
@<License@>

@<os_specific public structs@>
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
		fprintf(stderr, "Unable to set 800x600 video: %s\n", SDL_GetError());
		exit(1);
	}

	window_set_2d_config();

	return;
}
@}
w, h - размеры окна
game_w, game_h - размеры окна в игре, они будут растягиваться под w, h

@d os_specific public prototypes @{
void window_create(void);
@}


Настройки OGL для вывода 2D графики:
@d os_specific functions @{
static void window_set_2d_config(void) {
	//glClearColor(0, 0, 0, 0);
	//glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_TEXTURE_2D);

	@<window_set_2d_config OGL blend@>

	glViewport(0, 0, w, h);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	glOrtho(0, game_w, game_h, 0, 0, 1);

	glDisable(GL_DEPTH_TEST);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}
@}

Нам нужна поддержка прозрачности для вывода спрайтов с alpha каналом:
@d window_set_2d_config OGL blend @{
glEnable(GL_BLEND);
glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
@}

@d os_specific private prototypes @{
static void window_set_2d_config(void);
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

	return img;
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
/*void image_draw_corner(int id, int x, int y, float rot, float scale) {
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
}*/
@}

@d os_specific public prototypes @{@-
//void image_draw_corner(int id, int x, int y, float rot, float scale);
@}



Функция вывода изображения с центра:
@d os_specific functions @{
void image_draw_center(int id, int x, int y, float rot, float scale) {
	ImageList *img = &image_list[id];

	image_draw_center_t(id, x, y,
		0, 0, img->w, img->h,
		rot, scale);
/*
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
*/
}

void image_draw_center_t(int id, int x, int y,
		int tx1, int ty1, int tx2, int ty2,
		float rot, float scale) {
	ImageList *img = &image_list[id];
	int w = tx2 - tx1;
	int h = ty2 - ty1;

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	glBegin(GL_QUADS);
		glTexCoord2f((float)tx1/(float)img->w,
			(float)ty1/(float)img->h);
		glVertex2i(-w/2, -h/2);

		glTexCoord2f((float)tx2/(float)img->w,
			(float)ty1/(float)img->h);
		glVertex2i(w/2, -h/2);

		glTexCoord2f((float)tx2/(float)img->w,
			(float)ty2/(float)img->h);
		glVertex2i(w/2, h/2);

		glTexCoord2f((float)tx1/(float)img->w,
			(float)ty2/(float)img->h);
		glVertex2i(-w/2, h/2);
	glEnd();
}

void image_draw_center_t_mirror(int id, int x, int y,
		int tx1, int ty1, int tx2, int ty2,
		float rot, float scale) {
	ImageList *img = &image_list[id];
	int w = tx2 - tx1;
	int h = ty2 - ty1;

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	glBegin(GL_QUADS);
		glTexCoord2f((float)tx1/(float)img->w,
			(float)ty1/(float)img->h);
		glVertex2i(w/2, -h/2);

		glTexCoord2f((float)tx2/(float)img->w,
			(float)ty1/(float)img->h);
		glVertex2i(-w/2, -h/2);

		glTexCoord2f((float)tx2/(float)img->w,
			(float)ty2/(float)img->h);
		glVertex2i(-w/2, h/2);

		glTexCoord2f((float)tx1/(float)img->w,
			(float)ty2/(float)img->h);
		glVertex2i(w/2, h/2);
	glEnd();
}
@}

@d os_specific public prototypes @{
void image_draw_center(int id, int x, int y, float rot, float scale);
void image_draw_center_t(int id, int x, int y, int tx1, int ty1, int tx2, int ty2, float rot, float scale);
void image_draw_center_t_mirror(int id, int x, int y, int tx1, int ty1, int tx2, int ty2, float rot, float scale);
@}

Добавим функцию с помощью которой можно рисовать часть картинки:
@d os_specific functions @{
void image_draw_corner(int id, int x, int y,
	int tx1, int ty1, int tx2, int ty2,
	float scale, int color) {

	ImageList *img = &image_list[id];
	int w = tx2 - tx1;
	int h = ty2 - ty1;

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	//glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	switch(color) {
		@<os_specific switch colors@>
		default:
			fprintf(stderr, "\nUnknown color\n");
			exit(1);
	}

	glBegin(GL_QUADS);
		glTexCoord2f((float)tx1/(float)img->w,
			(float)ty1/(float)img->h);
		glVertex2i(0, 0);

		glTexCoord2f((float)tx2/(float)img->w,
			(float)ty1/(float)img->h);
		glVertex2i(w, 0);

		glTexCoord2f((float)tx2/(float)img->w,
			(float)ty2/(float)img->h);
		glVertex2i(w, h);

		glTexCoord2f((float)tx1/(float)img->w,
			(float)ty2/(float)img->h);
		glVertex2i(0, h);
	glEnd();

	glColor3ub(255,255,255);
}
@}

@d os_specific public prototypes @{
void image_draw_corner(int id, int x, int y,
	int tx1, int ty1, int tx2, int ty2,
	float scale, int color);
@}

@d os_specific public structs @{
enum {
	color_white, color_red, color_blue, color_green
};
@}

@d os_specific switch colors @{@-
case color_white:
	glColor3ub(255,255,255);
	break;
case color_red:
	glColor3ub(255,155,155);
	break;
case color_green:
	glColor3ub(155,255,155);
	break;
case color_blue:
	glColor3ub(155,155,255);
	break;
@}

Функция возврата процессорного времени OS:
@d os_specific public prototypes @{
void get_processor_time(void);
@}

@d os_specific functions @{
void get_processor_time(void) {
	SDL_Delay(0);
}
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

#include <stdint.h>

@<Character public macros@>
@<Character public structs@>
@<Character public prototypes@>
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
@d Character private structs @{@-
static CharacterList *pool;

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

@d Character public prototypes @{@-
CharacterList *character_reimu_create();
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

@d Character public prototypes @{@-
CharacterList *character_marisa_create();
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

@d Character public prototypes @{@-
void characters_update_all_time_points(void);
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

@d Character public prototypes @{@-
void characters_ai_control(void);
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

@d Character public prototypes @{@-
void characters_draw(void);
@}

Конкретные функции рисования для различных персонажей:
FIXME: нет анимации, смотреть у blue_fairy
@d Draw functions for different characters @{
static void character_reimu_draw(CharacterList *character) {
	static int id = -1;

	if(id == -1)
		id = image_load("aya.png");

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.1);
}

static void character_marisa_draw(CharacterList *character) {
	static int id = -1;

	if(id == -1)
		id = image_load("marisa.png");

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
@d Character types @{@-
character_blue_moon_fairy,
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
	при прошлой вырисовке персонажа(для продолжения	анимации); обнулять в конструкторе.
movement_animation - фаза анимации; вначале равна 0, инкрементируется там же где уменьшается
	time points; обнуляется в функции вырисовки; необходимо обнулять в конструкторе.

Я пытался сделать анимацию как в player, те была ещё переменная horizontal, которая была
	или 0, или -1, или 1. Но из-за того, что функция рисования линии не определяла движение
	по диагонали, персонаж постоянно дёргался(смотрел то вперёд, то в сторону). Пришлось
	делать с move_x, но это не плохо(кажется).

Используются три точки как и описано выше.

@d Character public prototypes @{@-
CharacterList *character_blue_moon_fairy_create(int begin_x, int begin_y, int to_x, int to_y, int end_x, int end_y);
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
@d character_set_weak_time_point_x other characters @{@-
case character_blue_moon_fairy:
	character_blue_moon_fairy_set_weak_time_point_x(character);
	break;
@}

@d character_set_weak_time_point_y other characters @{@-
case character_blue_moon_fairy:
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
@d characters_update_all_time_points other characters @{@-
case character_blue_moon_fairy:
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
@d characters_ai_control other characters @{@-
case character_blue_moon_fairy:
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
@d character_blue_moon_fairy_ai_control move to down @{@-
if(*step_of_movement == 0) {
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
@d character_blue_moon_fairy_ai_control wait @{@-
if(*step_of_movement == 1) {
	(*time)--;

	if(*time == 0)
		*step_of_movement = 2;
}
@}

Летим к конечной точке:
@d character_blue_moon_fairy_ai_control go away @{@-
if(*step_of_movement == 2) {
	*move_x = *end_x;
	*move_y = *end_y;
	*step_of_movement = 3;
}
@}

@d character_blue_moon_fairy_ai_control move to up @{@-
if(*step_of_movement == 3) {
	character_move_to_point(character, CMA(blue_moon_fairy, move_percent),
		CMA(blue_moon_fairy, time_point_for_movement_x), *move_x, *move_y);

	*speed = 130 - pow(101, *move_percent/100.0) + 1;
	if(*speed > 100)
		*speed = 100;

	if(*move_percent == 0)
		*step_of_movement = 4;
}
@}

@d character_blue_moon_fairy_ai_control remove @{@-
if(*step_of_movement == 4) {
	if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
		character->y < -25 || character->y > GAME_FIELD_H + 25) {
		character_free(character);
	}
}
@}
Фея после достижения конечной точки исчезает только если она за пределами экрана.

Рисуем персонажа:
@d characters_draw other characters @{@-
case character_blue_moon_fairy:
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
		id = image_load("blue_fairy.png");

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

@d character_blue_moon_fairy_draw left @{@-
if(*last_horizontal != 1)
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

@d character_blue_moon_fairy_draw right @{@-
if(*last_horizontal != -1)
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
@d damage_calculate other enemy characters @{@-
case character_blue_moon_fairy:
	if(bullet->bullet_type == bullet_reimu_first)
		character->hp -= 1000;
	break;
@}



Феи с кроличьими ушами.


@d Character types @{@-
character_blue_moon_bunny_fairy,
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

@d Character public prototypes @{@-
CharacterList *character_blue_moon_bunny_fairy_create(int begin_x, int begin_y, int to_x, int to_y, int end_x, int end_y);
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

@d character_set_weak_time_point_x other characters @{@-
case character_blue_moon_bunny_fairy:
	character_blue_moon_bunny_fairy_set_weak_time_point_x(character);
	break;
@}

@d character_set_weak_time_point_y other characters @{@-
case character_blue_moon_bunny_fairy:
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

@d characters_update_all_time_points other characters @{@-
case character_blue_moon_bunny_fairy:
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

@d characters_ai_control other characters @{@-
case character_blue_moon_bunny_fairy:
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
@d character_blue_moon_bunny_fairy_ai_control move to down @{@-
if(*step_of_movement == 0) {
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
@d character_blue_moon_bunny_fairy_ai_control wait @{@-
if(*step_of_movement == 1) {
	(*time)--;

	if(*time == 0)
		*step_of_movement = 2;
}
@}

Летим к конечной точке:
@d character_blue_moon_bunny_fairy_ai_control go away @{@-
if(*step_of_movement == 2) {
	*move_x = *end_x;
	*move_y = *end_y;
	*step_of_movement = 3;
}
@}

@d character_blue_moon_bunny_fairy_ai_control move to up @{@-
if(*step_of_movement == 3) {
	*speed = 10;
	character_move_to_point(character, CMA(blue_moon_bunny_fairy, move_percent),
		CMA(blue_moon_bunny_fairy, time_point_for_movement_x), *move_x, *move_y);

	if(*move_percent == 0)
		*step_of_movement = 4;
}
@}

@d character_blue_moon_bunny_fairy_ai_control remove @{@-
if(*step_of_movement == 4) {
	if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
		character->y < -25 || character->y > GAME_FIELD_H + 25) {
		character_free(character);
	}
}
@}
Фея после достижения конечной точки исчезает только если она за пределами экрана.


Рисуем персонажа:
@d characters_draw other characters @{@-
case character_blue_moon_bunny_fairy:
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
		id = image_load("blue_fairy.png");

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

@d character_blue_moon_bunny_fairy_draw left @{@-
if(*last_horizontal != 1)
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

@d character_blue_moon_bunny_fairy_draw right @{@-
if(*last_horizontal != -1)
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
@d damage_calculate other enemy characters @{@-
case character_blue_moon_bunny_fairy:
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

@d Character types @{@-
character_yellow_fire,
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

@d Character public prototypes @{@-
CharacterList *character_yellow_fire_create(CharacterList *parent, int angle, int is_fire, CharacterList *sister);
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

@d character_set_weak_time_point_x other characters @{@-
case character_yellow_fire:
	character_yellow_fire_set_weak_time_point_x(character);
	break;
@}

@d character_set_weak_time_point_y other characters @{@-
case character_yellow_fire:
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

@d characters_update_all_time_points other characters @{@-
case character_yellow_fire:
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

@d characters_ai_control other characters @{@-
case character_yellow_fire:
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

@d characters_draw other characters @{@-
case character_yellow_fire:
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
		id = image_load("sparks.png");

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
@d damage_calculate other enemy characters @{@-
case character_yellow_fire:
	if(bullet->bullet_type == bullet_reimu_first)
		character->hp -= 1000;
	break;
@}



Серые завихрения

Похоже что летят по прямой. Не стреляют.

@d Character types @{@-
character_gray_swirl,
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

@d Character public prototypes @{@-
CharacterList *character_gray_swirl_create(int begin_x, int begin_y, int end_x, int end_y);
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

@d character_set_weak_time_point_x other characters @{@-
case character_gray_swirl:
	character_gray_swirl_set_weak_time_point_x(character);
	break;
@}

@d character_set_weak_time_point_y other characters @{@-
case character_gray_swirl:
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

@d characters_update_all_time_points other characters @{@-
case character_gray_swirl:
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

@d characters_ai_control other characters @{@-
case character_gray_swirl:
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

@d character_gray_swirl_ai_control remove @{@-
if(*move_percent == 100)
	if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
		character->y < -25 || character->y > GAME_FIELD_H + 25) {
		character_free(character);
	}
@}

Рисуем серое завихрение:
@d characters_draw other characters @{@-
case character_gray_swirl:
	character_gray_swirl_draw(character);
	break;
@}

@d Draw functions for different characters @{
static void character_gray_swirl_draw(CharacterList *character) {
	int *const movement_animation = &character->args[CMA(gray_swirl, movement_animation)];

	static int id = -1;

	if(id == -1)
		id = image_load("sparks.png");

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
@d damage_calculate other enemy characters @{@-
case character_gray_swirl:
	if(bullet->bullet_type == bullet_reimu_first)
		character->hp -= 1000;
	break;
@}


Wriggle Nightbug

 - похоже что летает беспорядочно. Берёт случайную точку и летит к ней.
 - все время качается вверх-вниз.
 - когда каким типом пуль атакует непонятно

@d Character types @{@-
character_wriggle_nightbug,
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


@d Character public prototypes @{@-
CharacterList *character_wriggle_nightbug_create(int x, int y);
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

@d character_set_weak_time_point_x other characters @{@-
case character_wriggle_nightbug:
	character_wriggle_nightbug_set_weak_time_point_x(character);
	break;
@}

@d character_set_weak_time_point_y other characters @{@-
case character_wriggle_nightbug:
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

@d characters_update_all_time_points other characters @{@-
case character_wriggle_nightbug:
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

@d characters_ai_control other characters @{@-
case character_wriggle_nightbug:
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
@d character_wriggle_nightbug_ai_control move to center @{@-
if(*step_of_movement == 0) {
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

@d character_wriggle_nightbug_ai_control remove @{@-
if(*step_of_movement == 9) {
	if(character->x < -25 || character->x > GAME_FIELD_W + 25 ||
		character->y < -25 || character->y > GAME_FIELD_H + 25) {
		character_free(character);
	}
}
@}


@d characters_draw other characters @{@-
case character_wriggle_nightbug:
	character_wriggle_nightbug_draw(character);
	break;
@}

@d Draw functions for different characters @{
static void character_wriggle_nightbug_draw(CharacterList *character) {
	static int id = -1;

	if(id == -1)
		id = image_load("aya.png");

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.07);
}
@}

Повреждение от пуль:
@d damage_calculate other enemy characters @{@-
case character_wriggle_nightbug:
	if(bullet->bullet_type == bullet_reimu_first)
		character->hp -= 1000;
	break;
@}



===========================================================

Потокочистые версии парсера и лексера не позволяют(по крайней мере у меня
не получилось) перебрасываться частью инфы(например имя файла). Поэтому
я сделал одноразовые. Надо их чистить после их работы.
Парсер и лексер должны быть встроены, а не быть отдельным файлом, потому
как не все ОС позволят его запустить.

Грамматика danmakufu script

@o danmakufu.y @{

%code top {
@<License@>
}

%{
@<danmakufu.y C defines@>
%}

@<danmakufu.y Bison defines@>
%%
@<danmakufu.y grammar@>
%%
@<danmakufu.y code@>
@}

@d danmakufu.y C defines @{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "ast.h"

static int yylex (void);
extern FILE *yyin;
static char *global_filename;
@}
в filename хранится имя файла, который обрабатывается в данный момент
yyin - внутренняя переменная flex, из этого потока считываются лексемы.

@d danmakufu.y code @{
static void yyerror(const char *str) {
	fprintf(stderr, "error: %s\n", str);
}
@}

@d danmakufu.y C defines @{
static void yyerror(const char *str);
@}

Инициализируем таблицу символов, задаём имя первого файла,
начинаем синтаксический анализ:
@d danmakufu.y code @{
int main() {

	ast_init();

	danmakufu_parse("/dev/shm/Juuni Jumon - Summer Interlude/script/Juuni Jumon - Full Game.txt");

	// ast_clear();

	return 0;
}
@}

TODO: - сделать вместо main -- функцию которая принимает путь до скриптового файла
        Вместо init_x и clear_x выше используется ast_init, ast_clear, но(!)
        их надо вызывать ни в самой функции, которая принимает путь до файла(funcX), а в функции
        которая вызывает funcX, потом выполняет ast, а уже потом вызывает ast_clear.
      - лучше чистить мусор
      - почистить пространство имён
      - сделать оператор индекса [], оператором, а не костылём.
        Комментарий: лучше так не делать, потому что есть присваивание индексу, но
          нет присваивания функции.


Функция начала парсинга файла:
@d danmakufu.y code @{
AstCons *danmakufu_parse(char *filename) {
	global_filename = filename;

	yyin = fopen(filename, "r");

	if(yyparse() == 0)
		return toplevel_cons;

	return NULL;
}
@}
её и нужно вызывать, чтобы получить ast.

Подключаем лексер:
@d danmakufu.y code @{
#include "lex.yy.c"
@}


@d danmakufu.y C defines @{
AstCons *danmakufu_parse(char *filename);
@}

Глобальная переменная, хранит cons верхнего уровня, его будет возвращать
функция danmakufu_parse:
@d danmakufu.y C defines @{
static AstCons *toplevel_cons;
@}


@d danmakufu.y Bison defines @{
%locations
%error-verbose

%start script
@}

Тип для всех токенов:
@d danmakufu.y C defines @{
#define YYSTYPE void *
@}

@d danmakufu.y C defines @{
#ifndef YYLTYPE_IS_DECLARED

typedef struct YYLTYPE {
	int first_line;
	int first_column;
	int last_line;
	int last_column;
	char *filename;
} YYLTYPE;

#define YYLTYPE_IS_DECLARED 1
#endif
@}

@d danmakufu.y grammar @{
script        : /* empty */         { $$ = NULL; }
              | script toplevel     { @<danmakufu.y grammar concat script@> }
              ;
@}

@d danmakufu.y grammar concat script @{
if($2 != NULL) {
	if($1 == NULL)
		$$ = ast_dprogn($2, NULL);
	else
		$$ = ast_append($1, ast_add_cons($2, NULL));
} else
	$$ = $1;

toplevel_cons = $$;
@}

@d danmakufu.y grammar @{
toplevel      : SCRIPT_MAIN '{' lines '}'          { @<danmakufu.y grammar script main@> }
              | SCRIPT_CHILD SYMB '{' lines '}'    { @<danmakufu.y grammar script child@> }
              | macros
              ;
@}

@d danmakufu.y C defines @{
void *ast_ddefscriptmain(void *type, void *lines);
void *ast_ddefscriptchild(void *type, void *name, void *lines);
@}

Вернуть объект defscriptmain и defscriptchild:
@d danmakufu.y code @{
void *ast_ddefscriptmain(void *type, void *lines) {
	return ast_add_cons(ast_defscriptmain,
			ast_add_cons(type,
				ast_add_cons(lines, NULL)));
}

void *ast_ddefscriptchild(void *type, void *name, void *lines) {
	return ast_add_cons(ast_defscriptchild,
			ast_add_cons(type,
				ast_add_cons(name,
					ast_add_cons(lines, NULL))));
}
@}

@d danmakufu.y grammar script main @{
$$ = ast_ddefscriptmain($1, $3);
printf("SCRIPT_MAIN\n");
@}

@d danmakufu.y grammar script child @{
$$ = ast_ddefscriptchild($1, $2, $4);
@}

@d danmakufu.y grammar @{
macros        : M_TOUHOUDANMAKUFU   { @<danmakufu.y grammar declare script type@> }
              | M_TITLE             { @<danmakufu.y grammar declare title@> }
              | M_TEXT              { @<danmakufu.y grammar declare text@> }
              | M_IMAGE             { @<danmakufu.y grammar declare image@> }
              | M_BACKGROUND        { @<danmakufu.y grammar declare background@> }
              | M_BGM               { @<danmakufu.y grammar declare bgm@> }
              | M_PLAYLEVEL         { @<danmakufu.y grammar declare playlevel@> }
              | M_PLAYER            { @<danmakufu.y grammar declare player@> }
              | M_SCRIPTVERSION     { @<danmakufu.y grammar declare scriptversion@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_ddefvar(void *name, void *expr);
@}

Вернуть объект declare:
@d danmakufu.y code @{
void *ast_ddefvar(void *name, void *expr) {
	return ast_add_cons(ast_defvar,
			ast_add_cons(name,
				ast_add_cons(expr, NULL)));
}
@}

@d danmakufu.y grammar declare script type @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*touhoudanmakufu*"), $1);
@}

@d danmakufu.y grammar declare title @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*title*"), $1);
@}

@d danmakufu.y grammar declare text @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*text*"), $1);
@}

@d danmakufu.y grammar declare image @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*image*"), $1);
@}

@d danmakufu.y grammar declare background @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*background*"), $1);
@}

@d danmakufu.y grammar declare bgm @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*bgm*"), $1);
@}

@d danmakufu.y grammar declare playlevel @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*playlevel*"), $1);
@}

@d danmakufu.y grammar declare player @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*player*"), $1);
@}

@d danmakufu.y grammar declare scriptversion @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*scriptversion*"), $1);
@}

@d danmakufu.y grammar @{
lines         : /* empty */           { $$ = NULL; }
              | lines line            { @<danmakufu.y grammar concat lines@> }
              ;

line          : expr
              | dog_block
              | error ';'             { printf("file %s, line %d\n", @2.filename, @2.first_line); YYABORT; }
              ;
@}

@d danmakufu.y grammar concat lines @{
if($2 != NULL) {
	if($1 == NULL)
		$$ = ast_dprogn($2, NULL);
	else
		$$ = ast_append($1, ast_add_cons($2, NULL));
} else
	$$ = $1;
@}

@d danmakufu.y grammar @{
let           : LET SYMB '=' ret_expr ';'          { @<danmakufu.y grammar let with set@> }
              | LET SYMB ';'                       { @<danmakufu.y grammar let without set@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_dimplet(void *name, void *exprs);
@}

Вернуть объект implet:
@d danmakufu.y code @{
void *ast_dimplet(void *name, void *exprs) {
	return ast_add_cons(ast_implet,
			ast_add_cons(name,
				ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu.y grammar let with set @{
$$ = ast_dimplet($2, $4);
printf("LET %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar let without set @{
$$ = ast_dimplet($2, NULL);
$$ = ast_add_cons(ast_implet, ast_add_cons($2, NULL));
printf("LET %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar @{
dog_block     : DOG_NAME '{' exprs '}'   { @<danmakufu.y grammar dogs@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_ddog_name(void *name, void *exprs);
@}

Вернуть объект dog_name:
@d danmakufu.y code @{
void *ast_ddog_name(void *name, void *exprs) {
	return ast_add_cons(ast_dog_name,
			ast_add_cons(name, exprs));
}
@}

@d danmakufu.y grammar dogs @{
$$ = ast_ddog_name($1, $3);
printf("%s\n", ((AstSymbol*)$1)->name);
@}

Процедура:
@d danmakufu.y grammar @{
defsub_block  : SUB SYMB '{' exprs '}'   { @<danmakufu.y grammar function without parenthesis@> }
              ;
@}
имеет тот же обработчик, что и функция без параметров.

@d danmakufu.y grammar @{
deffunc_block : FUNCTION SYMB '(' ')' '{' exprs '}'      { @<danmakufu.y grammar function without lets@> }
              | FUNCTION SYMB '(' lets ')' '{' exprs '}' { @<danmakufu.y grammar function with lets@> }
              | FUNCTION SYMB '{' exprs '}'              { @<danmakufu.y grammar function without parenthesis@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_dfunction(void *name, void *lets, void *exprs);
@}

Вернуть объект function:
@d danmakufu.y code @{
void *ast_dfunction(void *name, void *lets, void *exprs) {
	return ast_add_cons(ast_defun,
			ast_add_cons(name,
				ast_add_cons(lets,
					ast_add_cons(exprs, NULL))));
}
@}

@d danmakufu.y grammar function without lets @{
$$ = ast_dfunction($2, NULL, $6);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar function with lets @{
$$ = ast_dfunction($2, $4, $7);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar function without parenthesis @{
$$ = ast_dfunction($2, NULL, $4);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar @{
deftask_block : TASK SYMB '(' ')' '{' exprs '}'       { @<danmakufu.y grammar task without lets@> }
              | TASK SYMB '(' lets ')' '{' exprs '}'  { @<danmakufu.y grammar task with lets@> }
              | TASK SYMB '{' exprs '}'               { @<danmakufu.y grammar task without parenthesis@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_dtask(void *name, void *lets, void *exprs);
@}

Вернуть объект task:
@d danmakufu.y code @{
void *ast_dtask(void *name, void *lets, void *exprs) {
	return ast_add_cons(ast_task,
				ast_add_cons(name,
					ast_add_cons(lets,
						ast_add_cons(exprs, NULL))));
}
@}

@d danmakufu.y grammar task without lets @{
$$ = ast_dtask($2, NULL, $6);
printf("TASK %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar task with lets @{
$$ = ast_dtask($2, $4, $7);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar task without parenthesis @{
$$ = ast_dtask($2, NULL, $4);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu.y grammar @{

exprs         : /* empty */          { $$ = NULL; }
              | exprs expr           { @<danmakufu.y grammar concatenate expr list@> }
              ;

expr          : ';'                  { $$ = NULL; }
              | deffunc_block
              | defsub_block
              | deftask_block
              | let
              | ret_expr ';'
              | call_keyword
              | set_op
              ;
@}
у "/* empty */" и ';' явно присваивание NULL не случайность, а необходимость. Иначе
  ';' будет вставлять какой-то мусор.

@d danmakufu.y C defines @{
void *ast_dprogn(void *first, void *others);
@}

Вернуть объект progn:
@d danmakufu.y code @{
void *ast_dprogn(void *first, void *others) {
	return ast_add_cons(ast_progn,
			ast_add_cons(first, others));
}
@}

@d danmakufu.y grammar concatenate expr list @{
if($2 != NULL) {
	if($1 == NULL)
		$$ = ast_dprogn($2, NULL);
	else
		$$ = ast_append($1, ast_add_cons($2, NULL));
} else
	$$ = $1;
@}

Выражение после times, while, ascent и descent:
@d danmakufu.y grammar @{
exprs_after_cycle : '{' exprs '}'              { $$ = $2; }
                  | LOOP '{' exprs '}'         { $$ = $3; }
                  ;
@}

@d danmakufu.y grammar @{
call_keyword  : YIELD ';'                                    { $$ = ast_add_cons(ast_yield, NULL); }
              | BREAK ';'                                    { $$ = ast_add_cons(ast_break, NULL); }
              | RETURN ret_expr ';'                          { @<danmakufu.y grammar return with expr@> }
              | RETURN ';'                                   { $$ = ast_add_cons(ast_return, NULL); }
              | LOOP '(' ret_expr ')' '{' exprs '}'          { @<danmakufu.y grammar loop with args@> }
              | LOOP '{' exprs '}'                           { @<danmakufu.y grammar loop without args@> }
              | TIMES '(' ret_expr ')' exprs_after_cycle     { @<danmakufu.y grammar times@> }
              | WHILE '(' ret_expr ')' exprs_after_cycle     { @<danmakufu.y grammar while@> }
              | LOCAL '{' exprs '}'                          { @<danmakufu.y grammar local@> }
              | ascent                                       { printf("ASCENT\n"); }
              | descent                                      { printf("DESCENT\n"); }
              | if
              | alternative
              ;
@}

@d danmakufu.y C defines @{
void *ast_dreturn(void *expr);
@}

Вернуть объект return:
@d danmakufu.y code @{
void *ast_dreturn(void *expr) {
	return ast_add_cons(ast_return,
			ast_add_cons(expr, NULL));
}
@}

@d danmakufu.y grammar return with expr @{
$$ = ast_dreturn($2);
@}

@d danmakufu.y C defines @{
void *ast_dloop(void *times, void *exprs);
@}

Вернуть объект loop:
@d danmakufu.y code @{
void *ast_dloop(void *times, void *exprs) {
	return ast_add_cons(ast_loop,
			ast_add_cons(times,
				ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu.y grammar loop with args @{
$$ = ast_dloop($3, $6);
printf("LOOP\n");
@}

@d danmakufu.y grammar loop without args @{
$$ = ast_dloop(NULL, $3);
printf("LOOP\n");
@}

@d danmakufu.y grammar times @{
$$ = ast_dloop($3, $5);
printf("TIMES\n");
@}

@d danmakufu.y C defines @{
void *ast_dwhile(void *cond, void *exprs);
@}

Вернуть объект while:
@d danmakufu.y code @{
void *ast_dwhile(void *cond, void *exprs) {
	return ast_add_cons(ast_while,
			ast_add_cons(cond,
				ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu.y grammar while @{
$$ = ast_dwhile($3, $5);
printf("WHILE\n");
@}


@d danmakufu.y C defines @{
void *ast_dblock(void *exprs);
@}

Вернуть объект block:
@d danmakufu.y code @{
void *ast_dblock(void *exprs) {
	return ast_add_cons(ast_block,
			ast_add_cons(exprs, NULL));
}
@}

@d danmakufu.y grammar local @{
$$ = ast_dblock($3);
printf("LOCAL\n");
@}


Danmakufu script'ный switch:
@d danmakufu.y grammar @{
alternative   : ALTERNATIVE '(' ret_expr ')' case others   { @<danmakufu.y grammar alternative with others@> }
              | ALTERNATIVE '(' ret_expr ')' case          { @<danmakufu.y grammar alternative without others@> }
              ;

case          : CASE '(' args ')' '{' exprs '}'            { @<danmakufu.y grammar case1@> }
              | case CASE '(' args ')' '{' exprs '}'       { @<danmakufu.y grammar case2@> }
              ;

others        : OTHERS '{' exprs '}'                       { @<danmakufu.y grammar other@> }
              ;
@}
Выглядит как говно, зато без конфликта shift/reduce.

@d danmakufu.y C defines @{
void *ast_dalternative(void *cond, void *case_, void *others_);
void *ast_dcase(void *args, void *exprs);
@}

Вернуть объект alternative:
@d danmakufu.y code @{
void *ast_dalternative(void *cond, void *case_, void *others_) {
	return ast_add_cons(ast_alternative,
			ast_add_cons(cond,
				ast_add_cons(ast_dlist(case_),
					ast_add_cons(others_, NULL))));
}
@}

Вернуть объект case:
@d danmakufu.y code @{
void *ast_dcase(void *args, void *exprs) {
	return ast_add_cons(ast_case,
			ast_add_cons(ast_dlist(args),
				ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu.y grammar alternative with others @{
$$ = ast_dalternative($3, $5, $6);
printf("ALTERNATIVE\n");
@}

@d danmakufu.y grammar alternative without others @{
$$ = ast_dalternative($3, $5, NULL);
printf("ALTERNATIVE\n");
@}

@d danmakufu.y grammar case1 @{
$$ = ast_add_cons(ast_dcase($3, $6), NULL);
printf("CASE\n");
@}

Если не первый case:
@d danmakufu.y grammar case2 @{
$$ = ast_append($1, ast_add_cons(ast_dcase($4, $7), NULL));
printf("CASE\n");
@}

@d danmakufu.y grammar other @{
$$ = $3;
printf("OTHERS\n");
@}

@d danmakufu.y grammar @{
ascent        : ASCENT '(' LET SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu.y grammar ascent with let@> }
              | ASCENT '(' SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu.y grammar ascent without let@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_dxcent(void *xcent, void *symb, void *from, void *to, void *exprs);
@}

Вернуть объект ascent или descent:
@d danmakufu.y code @{
void *ast_dxcent(void *xcent, void *symb, void *from, void *to, void *exprs) {
	return ast_add_cons(xcent,
			ast_add_cons(symb,
				ast_add_cons(from,
					ast_add_cons(to,
						ast_add_cons(exprs, NULL)))));
}
@}
ascent и descent -- геморой в будущем, они вводят лишние понятия, которые можно заменить
  с помощью for(do). Возможно стоит заменить код выше, и делать преобразование в обычный do
  вместо введения ast_ascent и ast_descent.

@d danmakufu.y grammar ascent with let @{
$$ = ast_dxcent(ast_ascent, ast_dimplet($4, NULL), $6, $8, $10);
@}

@d danmakufu.y grammar ascent without let @{
$$ = ast_dxcent(ast_ascent, $3, $5, $7, $9);
@}

@d danmakufu.y grammar @{
descent       : DESCENT '(' LET SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu.y grammar descent with let@> }
              | DESCENT '(' SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu.y grammar descent without let@> }
              ;
@}

@d danmakufu.y grammar descent with let @{
$$ = ast_dxcent(ast_descent, ast_dimplet($4, NULL), $6, $8, $10);
@}

@d danmakufu.y grammar descent without let @{
$$ = ast_dxcent(ast_descent, $3, $5, $7, $9);
@}


@d danmakufu.y grammar @{
if            : IF '(' ret_expr ')' '{' exprs '}' else_if    { @<danmakufu.y grammar if@> }
              ;

else_if       : /* empty */                                  { $$ = NULL; }
              | ELSE if                                      { @<danmakufu.y grammar else if@> }
              | ELSE '{' exprs '}'                           { @<danmakufu.y grammar else@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_dif(void *cond, void *then, void *else_);
@}

Вернуть объект if:
@d danmakufu.y code @{
void *ast_dif(void *cond, void *then, void *else_) {
	return ast_add_cons(ast_if,
			ast_add_cons(cond,
				ast_add_cons(then, else_)));
}
@}

@d danmakufu.y grammar if @{
$$ = ast_dif($3, $6, $8);
printf("IF %d\n", @1.first_line);
@}

@d danmakufu.y grammar else if @{
$$ = $2;
printf("ELSE ");
@}

@d danmakufu.y grammar else @{
$$ = $3;
printf("ELSE\n");
@}

@d danmakufu.y grammar @{
indexing         : array '[' ret_expr ']'                         { @<danmakufu.y grammar index@> }
                 | array '[' ret_expr DOUBLE_DOT ret_expr ']'     { @<danmakufu.y grammar slice@> }
                 | SYMB '[' ret_expr ']'                          { @<danmakufu.y grammar index@> }
                 | SYMB '[' ret_expr DOUBLE_DOT ret_expr ']'      { @<danmakufu.y grammar slice@> }
                 | call_func '[' ret_expr ']'                     { @<danmakufu.y grammar index@> }
                 | call_func '[' ret_expr DOUBLE_DOT ret_expr ']' { @<danmakufu.y grammar slice@> }
                 | indexing '[' ret_expr ']'                      { @<danmakufu.y grammar index@> }
                 | indexing '[' ret_expr DOUBLE_DOT ret_expr ']'  { @<danmakufu.y grammar slice@> }
                 ;
@}

@d danmakufu.y grammar index @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("index"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
printf("INDEX\n");
@}

@d danmakufu.y grammar slice @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("slice"),
		ast_add_cons($1,
			ast_add_cons($3,
				ast_add_cons($5, NULL))));
printf("SLICE\n");
@}

@d danmakufu.y grammar @{
call_func        : SYMB '(' ')'                       { @<danmakufu.y grammar call without args@> }
                 | SYMB '(' args ')'                  { @<danmakufu.y grammar call with args@> }
                 ;
@}
Одиночный символ -- тоже вызов функции

@d danmakufu.y C defines @{
void *ast_dfuncall(void *name, void *args);
@}

Вернуть объект funcall:
@d danmakufu.y code @{
void *ast_dfuncall(void *name, void *args) {
	return ast_add_cons(ast_funcall,
			ast_add_cons(name, args));
}
@}
может лучше убрать ast_funcall и сделать как в Scheme?

@d danmakufu.y grammar call without args @{
$$ = ast_dfuncall($1, NULL);
printf("CALL %s\n", ((AstSymbol*)$1)->name);
@}

@d danmakufu.y grammar call with args @{
$$ = ast_dfuncall($1, $3);
printf("CALL %s\n", ((AstSymbol*)$1)->name);
@}


Список аргументов при вызове функций и, возможно, чего-то ещё:
@d danmakufu.y grammar @{
args          : ret_expr              { @<danmakufu.y grammar args create list@> }
              | args ',' ret_expr     { @<danmakufu.y grammar args concatenate@> }
              ;
@}

@d danmakufu.y grammar args create list @{
$$ = ast_add_cons($1, NULL);
@}

@d danmakufu.y grammar args concatenate @{
$$ = ast_append($1, ast_add_cons($3, NULL));
@}

Список параметров при объявлении функции и
  прочих подобных штук:
@d danmakufu.y grammar @{
let_expr      : ret_expr
              | LET SYMB              { @<danmakufu.y grammar let_expr with let@> }
              ;

lets          : let_expr              { @<danmakufu.y grammar lets create list@> }
              | lets ',' let_expr     { @<danmakufu.y grammar lets concatenate@> }
              ;
@}

@d danmakufu.y grammar let_expr with let @{
$$ = ast_dimplet($2, NULL);
@}

@d danmakufu.y grammar lets create list @{
$$ = ast_add_cons($1, NULL);
@}

Соединим два определения параметра в список:
@d danmakufu.y grammar lets concatenate @{
$$ = ast_append($1, ast_add_cons($3, NULL));
@}

@d danmakufu.y grammar @{
set_op_elt    : SYMB
              | indexing
              ;

set_op        : set_op_elt '=' ret_expr ';'        { @<danmakufu.y grammar set operator@> }
              | set_op_elt ADD_SET_OP ret_expr ';' { @<danmakufu.y grammar add set operator@> }
              | set_op_elt SUB_SET_OP ret_expr ';' { @<danmakufu.y grammar sub set operator@> }
              | set_op_elt MUL_SET_OP ret_expr ';' { @<danmakufu.y grammar mul set operator@> }
              | set_op_elt DIV_SET_OP ret_expr ';' { @<danmakufu.y grammar div set operator@> }
              | set_op_elt INC_OP ';'              { @<danmakufu.y grammar successor@> }
              | set_op_elt DEC_OP ';'              { @<danmakufu.y grammar predcessor@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_dsetq(void *lval, void *rval);
@}

Вернуть объект setq:
@d danmakufu.y code @{
void *ast_dsetq(void *lval, void *rval) {
	return ast_add_cons(ast_setq,
			ast_add_cons(lval,
				ast_add_cons(rval, NULL)));
}
@}

@d danmakufu.y grammar set operator @{
$$ = ast_dsetq($1, $3);
@}

@d danmakufu.y grammar add set operator @{
$$ = ast_dsetq($1,
		ast_dfuncall(ast_add_symbol_to_tbl("add"),
			ast_add_cons($1,
				ast_add_cons($3, NULL))));
@}

@d danmakufu.y grammar sub set operator @{
$$ = ast_dsetq($1,
		ast_dfuncall(ast_add_symbol_to_tbl("subtract"),
			ast_add_cons($1,
				ast_add_cons($3, NULL))));
@}

@d danmakufu.y grammar mul set operator @{
$$ = ast_dsetq($1,
		ast_dfuncall(ast_add_symbol_to_tbl("multiply"),
			ast_add_cons($1,
				ast_add_cons($3, NULL))));
@}

@d danmakufu.y grammar div set operator @{
$$ = ast_dsetq($1,
		ast_dfuncall(ast_add_symbol_to_tbl("divide"),
			ast_add_cons($1,
				ast_add_cons($3, NULL))));
@}

@d danmakufu.y grammar successor @{
$$ = ast_dsetq($1,
		ast_dfuncall(ast_add_symbol_to_tbl("successor"),
			ast_add_cons($1, NULL)));
@}

@d danmakufu.y grammar predcessor @{
$$ = ast_dsetq($1,
		ast_dfuncall(ast_add_symbol_to_tbl("predcessor"),
			ast_add_cons($1, NULL)));
@}


Типы, которые возвращают значание:
@d danmakufu.y grammar @{
ret_expr      : NUM
              | SYMB
              | STRING
              | CHARACTER
              | call_func
              | indexing
              | array
              | ret_expr '+' ret_expr          { @<danmakufu.y grammar ret_expr add@> }
              | ret_expr '-' ret_expr          { @<danmakufu.y grammar ret_expr sub@> }
              | ret_expr '*' ret_expr          { @<danmakufu.y grammar ret_expr mul@> }
              | ret_expr '/' ret_expr          { @<danmakufu.y grammar ret_expr div@> }
              | ret_expr '%' ret_expr          { @<danmakufu.y grammar ret_expr mod@> }
              | ret_expr '<' ret_expr          { @<danmakufu.y grammar ret_expr less@> }
              | ret_expr LE_OP ret_expr        { @<danmakufu.y grammar ret_expr less-equal@> }
              | ret_expr '>' ret_expr          { @<danmakufu.y grammar ret_expr greater@> }
              | ret_expr GE_OP ret_expr        { @<danmakufu.y grammar ret_expr greater-equal@> }
              | ret_expr '^' ret_expr          { @<danmakufu.y grammar ret_expr pow@> }
              | ret_expr '~' ret_expr          { @<danmakufu.y grammar ret_expr concatenate@> }
              | ret_expr LOGICAL_OR ret_expr   { @<danmakufu.y grammar ret_expr logical or@> }
              | ret_expr LOGICAL_AND ret_expr  { @<danmakufu.y grammar ret_expr logical and@> }
              | ret_expr EQUAL_OP ret_expr     { @<danmakufu.y grammar ret_expr equal@> }
              | ret_expr NOT_EQUAL_OP ret_expr { @<danmakufu.y grammar ret_expr not equal@> }
              | NOT ret_expr                   { @<danmakufu.y grammar ret_expr not@> }
              | '-' ret_expr %prec NEG         { @<danmakufu.y grammar ret_expr negative@> }
              | '|' ret_expr '|'               { @<danmakufu.y grammar ret_expr abs@> }
              | '(' ret_expr ')'               { $$ = $2; }
              ;
@}

@d danmakufu.y grammar ret_expr add @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("add"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr sub @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("subtract"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr mul @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("multiply"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr div @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("divide"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr mod @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("remainder"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr less @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("<"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr less-equal @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("<="),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr greater @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl(">"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr greater-equal @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl(">="),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr pow @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("power"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr concatenate @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("concatenate"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr logical or @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("or"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr logical and @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("and"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr equal @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("equalp"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
@}

@d danmakufu.y grammar ret_expr not equal @{
void *o;
o = ast_dfuncall(ast_add_symbol_to_tbl("equalp"),
		ast_add_cons($1,
			ast_add_cons($3, NULL)));
$$ = ast_dfuncall(ast_add_symbol_to_tbl("not"),
		ast_add_cons(o, NULL));
@}

@d danmakufu.y grammar ret_expr not @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("not"),
		ast_add_cons($2, NULL));
@}

@d danmakufu.y grammar ret_expr negative @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("negative"),
		ast_add_cons($2, NULL));
@}

@d danmakufu.y grammar ret_expr abs @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("absolute"),
		ast_add_cons($2, NULL));
@}

@d danmakufu.y grammar @{
array         : '[' ']'                         { @<danmakufu.y grammar make-array empty@> }
              | '[' array_args ']'              { @<danmakufu.y grammar make-array@> }
              | '[' array_args ',' ']'          { @<danmakufu.y grammar make-array@> }
              ;

array_args    : ret_expr                        { @<danmakufu.y grammar create array_args@> }
              | array_args ',' ret_expr         { @<danmakufu.y grammar concat array_args@> }
              ;
@}

@d danmakufu.y C defines @{
void *ast_dmake_array(void *args);
@}

Вернуть объект make-array:
@d danmakufu.y code @{
void *ast_dmake_array(void *args) {
	if(args == NULL)
		return ast_add_cons(ast_make_array, NULL);
	else
		return ast_add_cons(ast_make_array,
				ast_add_cons(ast_dlist(args), NULL));
}
@}

@d danmakufu.y grammar make-array empty @{
$$ = ast_dmake_array(NULL);
printf("ARRAY\n");
@}

@d danmakufu.y grammar make-array @{
$$ = ast_dmake_array($2);
printf("ARRAY\n");
@}

@d danmakufu.y C defines @{
void *ast_dlist(void *args);
@}

Вернуть объект list:
@d danmakufu.y code @{
void *ast_dlist(void *args) {
	return ast_add_cons(ast_list, args);
}
@}

@d danmakufu.y grammar create array_args @{
$$ = ast_add_cons($1, NULL);
@}

@d danmakufu.y grammar concat array_args @{
$$ = ast_append($1, ast_add_cons($3, NULL));
@}

@d danmakufu.y Bison defines @{
%token LOGICAL_OR
%token LOGICAL_AND

%token EQUAL_OP
%token NOT_EQUAL_OP

%token ADD_SET_OP
%token SUB_SET_OP
%token MUL_SET_OP
%token DIV_SET_OP
%token INC_OP
%token DEC_OP

%left LOGICAL_OR LOGICAL_AND
%left EQUAL_OP NOT_EQUAL_OP '<' LE_OP '>' GE_OP
%left '-' '+' '~'
%left '*' '/' '%'
%left NEG NOT
%right '^'


%token NUM
%token STRING
%token CHARACTER

%token SYMB

%token DOG_NAME

%token SCRIPT_MAIN
%token SCRIPT_CHILD

%token LET
%token RETURN
%token IF
%token ELSE
%token YIELD
%token TASK
%token LOOP
%token TIMES
%token WHILE
%token LOCAL
%token ALTERNATIVE
%token CASE
%token OTHERS
%token ASCENT
%token DESCENT
%token IN
%token DOUBLE_DOT
%token BREAK
%token SUB
%token FUNCTION
@}


Макросы:
@d danmakufu.y Bison defines @{
%token M_TOUHOUDANMAKUFU
%token M_TITLE
%token M_TEXT
%token M_IMAGE
%token M_BACKGROUND
%token M_BGM
%token M_PLAYLEVEL
%token M_PLAYER
%token M_SCRIPTVERSION
@}

Лексика danmakufu script

@o danmakufu.lex @{
%{
@<danmakufu.lex C defines@>
%}

@<danmakufu.lex Lex defines@>
%%
@<danmakufu.lex vocabulary@>
%%
@<danmakufu.lex code@>
@}


@d danmakufu.lex Lex defines @{
%option noyywrap
@}

@d danmakufu.lex vocabulary @{
let                 return LET;
function            return FUNCTION;
sub                 return SUB;
task                return TASK;
yield               return YIELD;
break               return BREAK;
if                  return IF;
else                return ELSE;
loop                return LOOP;
times               return TIMES;
while               return WHILE;
local               return LOCAL;
alternative         return ALTERNATIVE;
case                return CASE;
others              return OTHERS;
ascent              return ASCENT;
descent             return DESCENT;
in                  return IN;
".."                return DOUBLE_DOT;
return              return RETURN;

script_enemy_main   { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_MAIN; }
script_stage_main   { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_MAIN; }
script_player_main  { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_MAIN; }

script_enemy        { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }
script_shot         { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }
script_spell        { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }
script_event        { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }

@Initialize         { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@MainLoop           { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@DrawLoop           { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@Finalize           { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@BackGround         { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@DrawTopObject      { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}

\+                  return '+';
-                   return '-';
\*                  return '*';
\/                  return '/';
%                   return '%';
\^                  return '^';
\<                  return '<';
"<="                return LE_OP;
\>                  return '>';
">="                return GE_OP;
=                   return '=';
;                   return ';';
~                   return '~';
,                   return ',';

\!                  return NOT;

\(                  return '(';
\)                  return ')';
\{                  return '{';
\}                  {@<danmakufu.lex closed curly bracket@>
                    }
\[                  return '[';
\]                  return ']';

"||"                return LOGICAL_OR;
&&                  return LOGICAL_AND;

\\=                 return DIV_SET_OP;
"*="                return MUL_SET_OP;
-=                  return SUB_SET_OP;
"+="                return ADD_SET_OP;
"++"                return INC_OP;
--                  return DEC_OP;

==                  return EQUAL_OP;
!=                  return NOT_EQUAL_OP;

false               { yylval = ast_false; return NUM; }
true                { yylval = ast_true; return NUM; }
pi                  { yylval = ast_pi; return NUM; }
@}

Будем возвращаеть перед каждым '}' ещё и ';':
@d danmakufu.lex closed curly bracket @{
if(lexer_curly_bracket == 0) {
	lexer_curly_bracket = 1;
	unput('}');
	return ';';
} else {
	lexer_curly_bracket = 0;
	return '}';
}
@}
Для '\n' не делать(!), так как можно запороть объявления функций на
  несколько строк. Пока не встретишь пример, что так делают не делать!

@d danmakufu.lex C defines @{
static int lexer_curly_bracket;
@}


@d danmakufu.lex vocabulary @{
{DIGIT}+                        { @<danmakufu.lex digits@>
                                }
{DIGIT}+"."{DIGIT}+             { @<danmakufu.lex digits@>
                                }
@}

@d danmakufu.lex digits @{
yylval = ast_add_number(atof(yytext));
return NUM;
@}

@d danmakufu.lex Lex defines @{
DIGIT               [0-9]
@}

@d danmakufu.lex vocabulary @{
{STRING}            { yylval = ast_add_string(remove_quotes(yytext, yyleng)); return STRING; }
{CHARACTER}         { yylval = ast_add_string(remove_quotes(yytext, yyleng)); return CHARACTER; }
@}

@d danmakufu.lex Lex defines @{
STRING              \"[^\"]*\"
CHARACTER           \'[^\']*\'
@}

Разрушающая функция, которая удаляет кавычки:
@d danmakufu.lex C defines @{
static char *remove_quotes(char *str, int len);
@}

@d danmakufu.lex code @{
static char *remove_quotes(char *str, int len) {
	int i, j;

	for(i = 0; i < len-1; i++)
		if(str[i] == '\"' || str[i] == '\'') {
			i++;
			break;
		}

	for(j = len-1; j > i; j--)
		if(str[j] == '\"' || str[j] == '\'') {
			str[j] = '\0';
			break;
		}

	return &str[i];
}
@}

Добавляем найденный символ в таблицу и возвращаем токен синтаксическому анализатору:
@d danmakufu.lex vocabulary @{
[[:alpha:]_][[:alnum:]_]*    { yylval = ast_add_symbol_to_tbl(yytext); return SYMB; }
@}


Макросы:
@d danmakufu.lex vocabulary @{
#TouhouDanmakufu              { yylval = NULL; return M_TOUHOUDANMAKUFU; }
#TouhouDanmakufu{IN_BRACKETS} { @<danmakufu.lex vocabulary to-string@>
                                return M_TOUHOUDANMAKUFU; }
#\x93\x8c\x95\xfb\x92\x65\x96\x8b\x95\x97              { yylval = NULL; return M_TOUHOUDANMAKUFU; }
#\x93\x8c\x95\xfb\x92\x65\x96\x8b\x95\x97{IN_BRACKETS} { @<danmakufu.lex vocabulary to-string@>
                                                         return M_TOUHOUDANMAKUFU; }
#Title{IN_BRACKETS}          { @<danmakufu.lex vocabulary to-string@>
                               return M_TITLE; }
#Text{IN_BRACKETS}           { @<danmakufu.lex vocabulary to-string@>
                               return M_TEXT; }
#Image{IN_BRACKETS}          { @<danmakufu.lex vocabulary to-string@>
                               return M_IMAGE; }
#BackGround{IN_BRACKETS}     { @<danmakufu.lex vocabulary to-string@>
                               return M_BACKGROUND; }
#BGM{IN_BRACKETS}            { @<danmakufu.lex vocabulary to-string@>
                               return M_BGM; }
#PlayLevel{IN_BRACKETS}      { @<danmakufu.lex vocabulary to-string@>
                               return M_PLAYLEVEL; }
#Player{IN_BRACKETS}         { @<danmakufu.lex vocabulary to-string@>
                               return M_PLAYER; }
#ScriptVersion{IN_BRACKETS}  { @<danmakufu.lex vocabulary to-string@>
                               return M_SCRIPTVERSION; }
@<danmakufu.lex vocabulary include_file@>
@}

Текст в квадратных скобках:
@d danmakufu.lex Lex defines @{
IN_BRACKETS         \[[^\]]*\]
@}

Достанем текст из квадратных скобок и вернём объект "строка":
@d danmakufu.lex vocabulary to-string @{
yylval = ast_add_string(find_and_remove_quotes_in_macros(yytext, yyleng));
@}


Разрушающая функция, используемая в макросах(#), которая ищет текст
  содержащийся в квадратных скобках, удаляет кавычки(при необходимости) и возвращает
  этот текст:
@d danmakufu.lex C defines @{
static char *find_and_remove_quotes_in_macros(char *str, int len);
@}

@d danmakufu.lex code @{
static char *find_and_remove_quotes_in_macros(char *str, int len) {
	int i, j;

	@<find_and_remove_quotes_in_macros forward@>
	@<find_and_remove_quotes_in_macros backward@>

	str[j] = '\0';
	return &str[i];
}
@}

Ищем открывающую скобку:
@d find_and_remove_quotes_in_macros forward @{
for(i = 0; i < len-1; i++)
	if(str[i] == '[') {
		i++;
		break;
	}
@}
когда найдём, то переходим на следующий символ, так как
  скобка нас не интересует. Выхода за границу массива нет,
  потому что len-1.

Пропускаем пробелы и одну кавычку после них, если она есть:
@d find_and_remove_quotes_in_macros forward @{
for(; i < len-1; i++)
	if(str[i] != ' ' && str[i] != '\t')
		break;
if(str[i] == '\"')
	i++;
@}
до len-1, так как там есть по крайней мере ']'

Ищем закрывающую скобку:
@d find_and_remove_quotes_in_macros backward @{
for(j = len-1; j > i; j--)
	if(str[j] == ']')
		break;
@}

Пропускаем пробелы и одну кавычку перед ниими, если она есть:
@d find_and_remove_quotes_in_macros backward @{
if(j != i) {
	for(j = j-1; j > i; j--)
		if(str[j] != ' ' && str[j] != '\t')
			break;
	if(str[j] != '\"')
		j++;
}
@}
после прошлого шага j указывает на ']' => искать будем с j-1.
Проверка j != i нужна для случая пустых скобок "[]"(надо обратить внимание на то,
  что иначе j = j-1, те побочный эффект).

Пропускаем пробелы и символы конца строки:
@d danmakufu.lex vocabulary @{
[ \t]+                     /* empty */
[\r\n]+                    { yylloc.first_line = yylineno; yylloc.filename = global_filename; }
@}
устанавливаем номер строки и имя файла.


Поддержка #include_function:
@d danmakufu.lex vocabulary include_file @{
#include_function             BEGIN(include);
<include>[ \t]*               /* empty */;
<include>{STRING}             { @<danmakufu.lex include_function start@>
                              }
<<EOF>>                       { @<danmakufu.lex include_function stop@>
                              }
@}
Закрывающие фигурные скобки расположены так забавно из-за ошибки в myweb(а как я её сейчас найду?-_-)

Этот блок выполняется, когда открывается include файл:
@d danmakufu.lex include_function start @{
int i;

yytext[yyleng-1] = '\0';

@<danmakufu.lex include_function replace backslash to slash@>

printf("#include %s\n", &yytext[1]);

@<danmakufu.lex include_function add numline to stack@>

yyin = fopen(&yytext[1], "r");

if(yyin == NULL)
	error("error with open file");

yypush_buffer_state(yy_create_buffer(yyin, YY_BUF_SIZE));

BEGIN(INITIAL);
@}
FIXME: когда файл не найден error("") иногда вызывает segfault

Этот блок выполняется, include файл заканчивается.
Закрываем файловый поток, и вызываем yypop_buffer_state, который
заменит yyin значением предыдущего файлового потока:
@d danmakufu.lex include_function stop @{
fclose(yyin);

yypop_buffer_state();

if(!YY_CURRENT_BUFFER)
	yyterminate();

@<danmakufu.lex include_function pop numline from stack@>
@}

@d danmakufu.lex Lex defines @{
%x include
@}

unix-specific костыль:
@d danmakufu.lex include_function replace backslash to slash @{
for(i = 1; i < yyleng-1; i++)
	if(yytext[i] == '\\')
		yytext[i] = '/';
@}
почему-то fopen в linux не хочет воспринимать '\'.

Определяем стек, где будем хранить
номер текущей строки и имя текущего файла, при открытии следующего файла с
помощью #include_function:
@d danmakufu.lex C defines @{
#define MAX_INCLUDE_DEPTH 20

#define INCLUDE_FILENAME_LEN 200

struct IncludeStack {
	int num_line;
	char filename[INCLUDE_FILENAME_LEN];
};

typedef struct IncludeStack IncludeStack;

static IncludeStack include_stack[MAX_INCLUDE_DEPTH];
static int pos_num_line;
@}

Функция которая помещает в стек текущее имя файла и номер текущей строки:
@d danmakufu.lex C defines @{
static void push_include(void) {
	if(include_stack[pos_num_line].filename != global_filename) {
		strncpy(include_stack[pos_num_line].filename, global_filename, INCLUDE_FILENAME_LEN);
		include_stack[pos_num_line].filename[INCLUDE_FILENAME_LEN-1] = '\0';
	}

	include_stack[pos_num_line].num_line = yylineno;

	pos_num_line++;
	if(pos_num_line == MAX_INCLUDE_DEPTH) {
		printf("MAX_INCLUDE_DEPTH\n");
		exit(1);
	}
}
@}
global_filename определён в bison

@d danmakufu.lex C defines @{
static IncludeStack *pop_include(void) {
	pos_num_line--;

	return &include_stack[pos_num_line];
}
@}

эта опция определяет переменную yylineno, которая содержит номер строки:
@d danmakufu.lex Lex defines @{
%option yylineno
@}
она работает как-то не так и обнулять приходится самому.

Сохраняем старые global_filename и yylineno, начинаем отсчёт с первой строки,
задаём имя файла полученое от лексера:
@d danmakufu.lex include_function add numline to stack @{
push_include();
yylineno = 1;
global_filename = &yytext[1];
@}

Возвращаем старые значения yylineno и global_filename:
@d danmakufu.lex include_function pop numline from stack @{
{
	printf("#close %s\n", global_filename);

	IncludeStack *is = pop_include();
	yylineno = is->num_line;
	global_filename = is->filename;
}
@}


Удаление комментариев, однострочных:
@d danmakufu.lex vocabulary @{
\/\/[^\r\n]*                  /* empty */;
@}
и многострочных:
@d danmakufu.lex vocabulary @{
"/*"                          BEGIN(comment);
<comment>{
	"*"+"/"                   BEGIN(0);
	[^*\n]+                   ;
	"*"[^/]                   ;
	\n                        ;
}
@}
без плюса в первом правиле валился на ****/, так как звёздочки съедались
  по две и на */ нехватало.

@d danmakufu.lex Lex defines @{
%x comment
@}


===========================================================

Таблица символов и cons'ы

@o ast.h @{
@<License@>

#include "dlist.h"

@<ast.h structs@>
@<ast.h prototypes@>
@}


@o ast.c @{
@<License@>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "ast.h"
#include "dlist.h"

@<ast.c structs@>
@<ast.c prototypes@>
@<ast.c functions@>
@}

Типы элементов:
@d ast.h structs @{
enum {
	ast_symbol,
	ast_cons,
	ast_number,
	ast_string,
	ast_character,
};
@}

Символ danmakufu:
@d ast.h structs @{
#define SYMBOL_MAX_LEN 40
struct AstSymbol {
	struct AstSymbol *prev;
	struct AstSymbol *next;
	struct AstSymbol *pool;
	int type;
	char name[SYMBOL_MAX_LEN];
};

typedef struct AstSymbol AstSymbol;
@}
type - указывает тип, всегда равен ast_symbol.
  Он нужен чтобы отличать в cons'ах атомы и другие cons'ы.

Список символов:
@d ast.c structs @{
static AstSymbol *symbols;
@}

Пулл символов и удалённых символов:
@d ast.c structs @{
static AstSymbol *symbols_pool;

static AstSymbol *symbols_pool_free;
static AstSymbol *symbols_end_pool_free;
@}
symbols_end_pool_free - ссылка на последний элемент symbols_pool_free

SYMBOL_ALLOC - аллоцируется слотов в самом начале
SYMBOL_ADD - добавляется при нехватке
@d ast.c structs @{
#define SYMBOL_ALLOC 1000
#define SYMBOL_ADD 100
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
static void symbols_free(AstSymbol *symbol) {
	if(symbol == symbols)
		symbols = symbols->next;

	if(symbols_pool_free == NULL)
		symbols_end_pool_free = symbol;

	dlist_free((DList*)symbol, (DList**)(&symbols_pool_free));
}
@}

Соединить symbols_pool_free с symbols_pool:
@d ast.c functions @{
static void symbols_pool_free_to_pool(void) {
	if(symbols_end_pool_free == NULL)
		return;

	symbols_end_pool_free->pool = symbols_pool;
	symbols_pool = symbols_pool_free;

	symbols_pool_free = NULL;
	symbols_end_pool_free = NULL;
}
@}

symbols_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
static AstSymbol *symbols_get_free_cell(void) {
	if(symbols_pool == NULL) {
		int k = (symbols == NULL) ? SYMBOL_ALLOC : SYMBOL_ADD;
		int i;

		symbols_pool = malloc(sizeof(AstSymbol)*k);
		if(symbols_pool == NULL) {
			fprintf(stderr, "\nCan't allocate memory for symbols' pool\n");
			exit(1);
		}

		for(i = 0; i < k-1; i++)
			symbols_pool[i].pool = &(symbols_pool[i+1]);
		symbols_pool[k-1].pool = NULL;
	}

	symbols = (AstSymbol*)dlist_alloc((DList*)symbols, (DList**)(&symbols_pool));

	return symbols;
}
@}

Функция поиска символа в таблице:
@d ast.c functions @{
static AstSymbol *find_symbol(const char *name) {
	AstSymbol *symbol;

	for(symbol = symbols; symbol != NULL; symbol = symbol->next)
		if(strcmp(symbol->name, name) == 0)
			return symbol;

	return NULL;
}
@}
NULL - если не найден.

Добавить элемент в таблицу:
@d ast.c functions @{
AstSymbol *ast_add_symbol_to_tbl(const char *name) {
	AstSymbol *symbol;

	symbol = find_symbol(name);
	if(symbol != NULL)
		return symbol;

	symbol = symbols_get_free_cell();

	symbol->type = ast_symbol;

	strncpy(symbol->name, name, SYMBOL_MAX_LEN);
	symbol->name[SYMBOL_MAX_LEN-1] = '\0';

	return symbol;
}
@}


@d ast.h prototypes @{
AstSymbol *ast_add_symbol_to_tbl(const char *name);
@}

Функция очистки:
@d ast.c functions @{
static void clear_symbols(void) {
	// BLA-BLA
}
@}
вызывать при выходе из игры. Хотя можно и после завершения скрипта,
  но зачем фрагментировать память?

Cons-пара danmakufu:
@d ast.h structs @{
DLIST_DEFSTRUCT(AstCons)
	int type;
	void *car;
	void *cdr;
DLIST_ENDS(AstCons)
@}
type - указывает тип, всегда равен ast_cons.

Список занятых cons'ов, пулл свободных cons'ов и удалённых cons'ов:
@d ast.c structs @{
DLIST_SPECIAL_VARS(conses, AstCons)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d ast.c structs @{
DLIST_ALLOC_VARS(conses, 10000, 1000)
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
DLIST_FREE_FUNC(conses, AstCons)
DLIST_END_FREE_FUNC(conses, AstCons)
@}

Соединить conses_pool_free с conses_pool:
@d ast.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(conses, AstCons)
@}

conses_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
DLIST_GET_FREE_CELL_FUNC(conses, AstCons)
@}

Добавить cons в массив:
@d ast.c functions @{
AstCons *ast_add_cons(void *car, void *cdr) {
	AstCons *c = conses_get_free_cell();

	c->type = ast_cons;
	c->car = car;
	c->cdr = cdr;

	return c;
}
@}

@d ast.h prototypes @{
AstCons *ast_add_cons(void *car, void *cdr);
@}

Функция очистки массива cons'ов:
@d ast.c functions @{
static void clear_conses(void) {
	// XXXYYYZZZ
}
@}
вызвать при выходе из игры(см. clear_symbols_tbl)


Тип число:
@d ast.h structs @{
struct AstNumber {
	struct AstNumber *prev;
	struct AstNumber *next;
	struct AstNumber *pool;
	int type;
	double number;
};

typedef struct AstNumber AstNumber;
@}
type == ast_number

Список чисел:
@d ast.c structs @{
static AstNumber *numbers;
@}

Пулл чисел и удалённых чисел:
@d ast.c structs @{
static AstNumber *numbers_pool;

static AstNumber *numbers_pool_free;
static AstNumber *numbers_end_pool_free;
@}
numbers_end_pool_free - ссылка на последний элемент numbers_pool_free

NUMBER_ALLOC - аллоцируется слотов в самом начале
NUMBER_ADD - добавляется при нехватке
@d ast.c structs @{
#define NUMBER_ALLOC 1000
#define NUMBER_ADD 300
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
static void numbers_free(AstNumber *number) {
	if(number == numbers)
		numbers = numbers->next;

	if(numbers_pool_free == NULL)
		numbers_end_pool_free = number;

	dlist_free((DList*)number, (DList**)(&numbers_pool_free));
}
@}

Соединить numbers_pool_free с numbers_pool:
@d ast.c functions @{
static void numbers_pool_free_to_pool(void) {
	if(numbers_end_pool_free == NULL)
		return;

	numbers_end_pool_free->pool = numbers_pool;
	numbers_pool = numbers_pool_free;

	numbers_pool_free = NULL;
	numbers_end_pool_free = NULL;
}
@}

numbers_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
static AstNumber *numbers_get_free_cell(void) {
	if(numbers_pool == NULL) {
		int k = (numbers == NULL) ? NUMBER_ALLOC : NUMBER_ADD;
		int i;

		numbers_pool = malloc(sizeof(AstNumber)*k);
		if(numbers_pool == NULL) {
			fprintf(stderr, "\nCan't allocate memory for numbers' pool\n");
			exit(1);
		}

		for(i = 0; i < k-1; i++)
			numbers_pool[i].pool = &(numbers_pool[i+1]);
		numbers_pool[k-1].pool = NULL;
	}

	numbers = (AstNumber*)dlist_alloc((DList*)numbers, (DList**)(&numbers_pool));

	return numbers;
}
@}


Функция поиска числа в таблице:
@d ast.c functions @{
static AstNumber *find_number(double num) {
	AstNumber *number;

	for(number = numbers; number != NULL; number = number->next)
		if(number->number == num)
			return number;

	return NULL;
}
@}
NULL - если не найден.

Добавить number в массив:
@d ast.c functions @{
AstNumber *ast_add_number(double num) {
	AstNumber *number;

	number = find_number(num);
	if(number != NULL)
		return number;

	number = numbers_get_free_cell();

	number->type = ast_number;
	number->number = num;

	return number;
}
@}

@d ast.h prototypes @{
AstNumber *ast_add_number(double num);
@}

Функция очистки:
@d ast.c functions @{
static void clear_numbers(void) {
	// YAHOOO
}
@}

Строка:
@d ast.h structs @{
struct AstString {
	struct AstString *prev;
	struct AstString *next;
	struct AstString *pool;
	int type;
	char *str;
	unsigned int len;
};

typedef struct AstString AstString;
@}
type == ast_string или ast_character
len - число байтов

Список строк:
@d ast.c structs @{
static AstString *strings;
@}

Пулл строк и удалённых строк:
@d ast.c structs @{
static AstString *strings_pool;

static AstString *strings_pool_free;
static AstString *strings_end_pool_free;
@}
strings_end_pool_free - ссылка на последний элемент strings_pool_free

STRING_ALLOC - аллоцируется слотов в самом начале
STRING_ADD - добавляется при нехватке
@d ast.c structs @{
#define STRING_ALLOC 300
#define STRING_ADD 50
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
DLIST_FREE_FUNC(strings, AstString)
	free(elm->str);
	elm->str = NULL;
DLIST_END_FREE_FUNC(strings, AstString)
@}

Соединить strings_pool_free с strings_pool:
@d ast.c functions @{
static void strings_pool_free_to_pool(void) {
	if(strings_end_pool_free == NULL)
		return;

	strings_end_pool_free->pool = strings_pool;
	strings_pool = strings_pool_free;

	strings_pool_free = NULL;
	strings_end_pool_free = NULL;
}
@}

strings_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
static AstString *strings_get_free_cell(void) {
	if(strings_pool == NULL) {
		int k = (strings == NULL) ? STRING_ALLOC : STRING_ADD;
		int i;

		strings_pool = malloc(sizeof(AstString)*k);
		if(strings_pool == NULL) {
			fprintf(stderr, "\nCan't allocate memory for strings' pool\n");
			exit(1);
		}

		for(i = 0; i < k-1; i++)
			strings_pool[i].pool = &(strings_pool[i+1]);
		strings_pool[k-1].pool = NULL;
	}

	strings = (AstString*)dlist_alloc((DList*)strings, (DList**)(&strings_pool));

	return strings;
}
@}


Добавить строку в таблицу:
@d ast.c functions @{
AstString *ast_add_string(const char *str) {
	AstString *string = strings_get_free_cell();

	string->type = ast_string;

	string->len = strlen(str);

	string->str = malloc((string->len + 1)*sizeof(char));
	if(string->str == NULL) {
		fprintf(stderr, "\nCan't allocate memory for symbols' pool\n");
		exit(1);
	}

	strcpy(string->str, str);

	return string;
}
@}

@d ast.h prototypes @{
AstString *ast_add_string(const char *str);
@}

Добавить символ в таблицу:
@d ast.c functions @{
AstString *ast_add_character(const char *str) {
	AstString *string = ast_add_string(str);
	string->type = ast_character;

	return string;
}
@}

@d ast.h prototypes @{
AstString *ast_add_character(const char *str);
@}

Функция очистки:
@d ast.c functions @{
static void clear_strings(void) {
	// BLA-BLA
}
@}

Инициализация ast:
@d ast.c functions @{
void ast_init(void) {
	ast_defun = ast_add_symbol_to_tbl("defun");
	ast_implet = ast_add_symbol_to_tbl("implet");
	ast_task = ast_add_symbol_to_tbl("task");
	ast_if = ast_add_symbol_to_tbl("if");
	ast_alternative = ast_add_symbol_to_tbl("alternative");
	ast_case = ast_add_symbol_to_tbl("case");
	ast_funcall = ast_add_symbol_to_tbl("funcall");
	ast_dog_name = ast_add_symbol_to_tbl("dog_name");
	ast_setq = ast_add_symbol_to_tbl("setq");
	ast_ascent = ast_add_symbol_to_tbl("ascent");
	ast_descent = ast_add_symbol_to_tbl("descent");
	ast_yield = ast_add_symbol_to_tbl("yield");
	ast_break = ast_add_symbol_to_tbl("break");
	ast_return = ast_add_symbol_to_tbl("return");
	ast_loop = ast_add_symbol_to_tbl("loop");
	ast_while = ast_add_symbol_to_tbl("while");
	ast_block = ast_add_symbol_to_tbl("block");
	ast_make_array = ast_add_symbol_to_tbl("make-array");
	ast_defscriptmain = ast_add_symbol_to_tbl("defscriptmain");
	ast_defscriptchild = ast_add_symbol_to_tbl("defscriptchild");
	ast_defvar = ast_add_symbol_to_tbl("defvar");
	ast_progn = ast_add_symbol_to_tbl("progn");
	ast_list = ast_add_symbol_to_tbl("list");

	ast_false = ast_add_number(0.0);
	ast_true = ast_add_number(1.0);
	ast_pi = ast_add_number(3.1415);
}
@}
FIXME: усложнённый язык! После того как вычислятор будет написан, стоит упростить
  язык виртуальной машины. Например вместо ascent, descent, loop, while сделать do.

Очистка ast:
@d ast.c functions @{
void ast_clear(void) {
	clear_symbols();
	clear_conses();
	clear_numbers();
	clear_strings();
}
@}
вызвать при выходе из игры(см. clear_symbols_tbl и clear_cons_array)

@d ast.h prototypes @{
void ast_init(void);
void ast_clear(void);
@}

На часть символов будем хранить указатели. Это ускорит сравнение:
@d ast.c structs @{
AstSymbol *ast_defun;
AstSymbol *ast_implet;
AstSymbol *ast_task;
AstSymbol *ast_if;
AstSymbol *ast_alternative;
AstSymbol *ast_case;
AstSymbol *ast_funcall;
AstSymbol *ast_dog_name;
AstSymbol *ast_setq;
AstSymbol *ast_ascent;
AstSymbol *ast_descent;
AstSymbol *ast_yield;
AstSymbol *ast_break;
AstSymbol *ast_return;
AstSymbol *ast_loop;
AstSymbol *ast_while;
AstSymbol *ast_block;
AstSymbol *ast_make_array;
AstSymbol *ast_defscriptmain;
AstSymbol *ast_defscriptchild;
AstSymbol *ast_defvar;
AstSymbol *ast_progn;
AstSymbol *ast_list;

AstNumber *ast_false;
AstNumber *ast_true;
AstNumber *ast_pi;
@}

@d ast.h structs @{
extern AstSymbol *ast_defun;
extern AstSymbol *ast_implet;
extern AstSymbol *ast_task;
extern AstSymbol *ast_if;
extern AstSymbol *ast_alternative;
extern AstSymbol *ast_case;
extern AstSymbol *ast_funcall;
extern AstSymbol *ast_dog_name;
extern AstSymbol *ast_setq;
extern AstSymbol *ast_ascent;
extern AstSymbol *ast_descent;
extern AstSymbol *ast_yield;
extern AstSymbol *ast_break;
extern AstSymbol *ast_return;
extern AstSymbol *ast_loop;
extern AstSymbol *ast_while;
extern AstSymbol *ast_block;
extern AstSymbol *ast_make_array;
extern AstSymbol *ast_defscriptmain;
extern AstSymbol *ast_defscriptchild;
extern AstSymbol *ast_defvar;
extern AstSymbol *ast_progn;
extern AstSymbol *ast_list;

extern AstNumber *ast_false;
extern AstNumber *ast_true;
extern AstNumber *ast_pi;
@}
implet - императивная версия let(не как в лиспе)

Добавим поддержку операций car и cdr для удобства доступа:
@d ast.h prototypes @{
AstCons *car(AstCons *cons);
AstCons *cdr(AstCons *cons);
AstCons *caar(AstCons *cons);
AstCons *cadr(AstCons *cons);
AstCons *cdar(AstCons *cons);
AstCons *cddr(AstCons *cons);
@}

@d ast.c functions @{
AstCons *car(AstCons *cons) {
	return cons->car;
}

AstCons *cdr(AstCons *cons) {
	return cons->cdr;
}

AstCons *caar(AstCons *cons) {
	return ((AstCons*)cons->car)->car;
}

AstCons *cadr(AstCons *cons) {
	return ((AstCons*)cons->cdr)->car;
}

AstCons *cdar(AstCons *cons) {
	return ((AstCons*)cons->car)->cdr;
}

AstCons *cddr(AstCons *cons) {
	return ((AstCons*)cons->cdr)->cdr;
}
@}
функции примитивны: казалось бы, зачем они? Но они позволяют уменьшить
  количество приведений типа(значит и размер кода), что есть хорошо.

Функция append:
@d ast.h prototypes @{
AstCons *ast_append(AstCons *cons, AstCons *to_back);
@}

@d ast.c functions @{
AstCons *ast_append(AstCons *cons, AstCons *to_back) {
	if(cons == NULL) {
		fprintf(stderr, "\nast_append: Cons == NULL\n");
		exit(1);
	}

	AstCons *c;
	for(c = cons; c->type == ast_cons && c->cdr != NULL; c = c->cdr);

	if(c->type != ast_cons) {
		fprintf(stderr, "\nast_append: It isn't cons\n");
		exit(1);
	}

	c->cdr = to_back;
	return cons;
}
@}
с той же целью, что и cdr() и car().

Функция печати, нужна для отладки:
@d ast.h prototypes @{
void ast_print(const AstCons *cons);
@}

@d ast.c prototypes @{
static void ast_print_helper(const void *obj, int shift, int skip_first_shift);
@}
shift - число пробелов в отступе

@d ast.c functions @{
void ast_print(const AstCons *cons) {
	ast_print_helper(cons, 0, 0);
}

static void ast_print_helper(const void *obj, int shift, int skip_first_shift) {
	int i;

	if(skip_first_shift == 0)
		for(i = 0; i < shift; i++)
			printf(" ");

	if(obj == NULL) {
		printf("NIL");
		return;
	}

	switch(((const AstCons*)obj)->type) {
		case ast_cons: {
			const AstCons *p;

			printf("(");
			for(p = obj;
				p->cdr != NULL && ((const AstCons*)p->cdr)->type == ast_cons;
				p = p->cdr) {
				ast_print_helper(p->car, shift+1, (p == obj) ? 1 : 0);
				printf("\n");
			}
			ast_print_helper(p->car, shift+1, (p == obj) ? 1 : 0);
			if(p->cdr != NULL) {
				printf(" .\n");
				ast_print_helper(p->cdr, shift+1, 0);
			}
			printf(")");

			/*
			const AstCons *cons = obj;
			printf("(cons\n");
			ast_print_helper(cons->car, shift+1, 0);
			printf("\n");
			ast_print_helper(cons->cdr, shift+1, 0);
			printf(")");
			*/
			break;
		}
		case ast_symbol: {
			const AstSymbol *symb = obj;
			printf("%s", symb->name);
			break;
		}
		case ast_string: {
			const AstString *str = obj;
			printf("\"%s\"", str->str);
			break;
		}
		case ast_character: {
			const AstString *chr = obj;
			printf("'%s'", chr->str);
			break;
		}
		case ast_number: {
			const AstNumber *num = obj;
			printf("%f", num->number);
			break;
		}
		default:
			fprintf(stderr, "\nast_print_helper: unknown object\n");
			exit(1);
			break;
	}
}
@}

===========================================================

Danmakufu вычислятор

Проблема в том что разных скриптов, в котором есть @BlaBla элементы,
  очень много: этажа, монстров итд
А ещё есть разные версии самого скрипта.

TODO: надо узнать, общее пространство имён(например объявленые функции) у разных скриптов
  или одно.


@o danmakufu.h @{
@<License@>

#include "dlist.h"

@<danmakufu.h structs@>
@<danmakufu.h prototypes@>
@}

@o danmakufu.c @{
@<License@>

#include "danmakufu.h"
#include "danmakufu_bytecode.h"

@<danmakufu.c structs@>
@<danmakufu.c prototypes@>
@<danmakufu.c functions@>
@}


Структура машины исполняющий байткод или native-код danmakufu:
@d danmakufu.h structs @{
struct DanmakufuMachine {
	int type;
	intptr_t *code;

	DanmakufuTask *tasks;
	DanmakufuTask *last_task;

	DanmakufuDict *global;
};

typedef struct DanmakufuMachine DanmakufuMachine;
@}
По сути DanmakufuMachine -- это script_xxx + макросы в заголовке
type - тип кода(bytecode, native)
code - байткод(похож на forth)
tasks - указатель на список задач; last_task - последняя задача в списке,
  чтобы легче было вставлять первую в конец.
global - словарь слов-символов forth-машины(содержит переменные, имена функций итд)
  TODO: global[32] - как насчёт хеширования?

Типы кода:
@d danmakufu.h structs @{
enum {
	danmakufu_bytecode,
	danmakufu_i386,
};
@}

Задача:
@d danmakufu.h structs @{
#define DANMAKUFU_TASK_STACK_SIZE 50
#define DANMAKUFU_TASK_RSTACK_SIZE 50
struct DanmakufuTask {
	struct DanmakufuTask *next;

	int ip;
	DanmakufuDictList *local;

	void *stack[DANMAKUFU_TASK_STACK_SIZE];
	int sp;

	void *rstack[DANMAKUFU_TASK_RSTACK_SIZE];
	int rp;
};

typedef DanmakufuTask DanmakufuTask;
@}
next - указатель на следующую задачу
ip - место выполнения процесса
local - указатель на список локальных словарей задачи(определения могут перекрываться)
stack - указывает на элементы из ast(например: ast_string или ast_number)
sp - позиция в стеке
rstack - стек адресов возврата
rp - позиция в стеке


Словарь:
@d danmakufu.h structs @{
DLIST_DEFSTRUCT(DanmakufuDict)
	AstSymbol *symb;
	void *ptr;
DLIST_ENDS(DanmakufuDict)
@}
указывает на символ и его значение.

Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_dicts, DanmakufuDict)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_dicts, 1000, 100)
@}
по-идее должно совпадать с теми же параметрами для AstSymbol

Функция для возвращения выделенных слотов обратно в пул:
@d danmakufu.c structs @{
DLIST_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
DLIST_END_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
@}
возможно сюда стоит вставить код освобождения содержимого ptr.

Соединить danmakufu_dicts_pool_free с danmakufu_dicts_pool:
@d danmakufu.c structs @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_dicts, DanmakufuDict)
@}

danmakufu_dicts_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c structs @{
DLIST_GET_FREE_CELL_FUNC(danmakufu_dicts, DanmakufuDict)
@}




Список словарей:
@d danmakufu.h structs @{
DLIST_DEFSTRUCT(DanmakufuDictList)
	DanmakufuDict *dict;
DLIST_ENDS(DanmakufuDictList)
@}

Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_dict_lists, DanmakufuDictList)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_dict_lists, 100, 20)
@}



Функция загрузки скрипта:
@d danmakufu.h prototypes @{
DanmakufuMachine *danmakufu_load_file(const char *filename);
@}

@d danmakufu.c functions @{
DanmakufuMachine *danmakufu_load_file(const char *filename) {
	AstCons *cons = danmakufu_parse(filename);
	if(cons == NULL) {
		fprintf(stderr, "\ndanmakufu_parse error\n");
		exit(1);
	}

	DanmakufuMachine *mach = malloc(sizeof(DanmakufuMachine));
	if(mach == NULL) {
		fprintf(stderr, "\nCan't allocate memory for danmakufu_machine\n");
		exit(1);
	}

	mach->type = danmakufu_bytecode;
	mach->code = danmakufu_compile_to_bytecode(cons);

	return mach;
}
@}
TODO: написать обработку ошибок при парсинге скрипта


===========================================================

Компиляция в байткод для danmakufu

@o danmakufu_bytecode.h @{
@<License@>

@<danmakufu_bytecode.h structs@>
@<danmakufu_bytecode.h prototypes@>
@}

@o danmakufu_bytecode.c @{
@<License@>

#include "danmakufu_bytecode.h"
#include "ast.h"

@<danmakufu_bytecode.c structs@>
@<danmakufu_bytecode.c prototypes@>
@<danmakufu_bytecode.c functions@>
@}

Коды байткода:
@d danmakufu_bytecode.h structs @{
enum {
	bc_lit,
	bc_setq,
	bc_drop,
	bc_decl,
	bc_scope_push,
	bc_scope_pop,
	bc_defun,
	bc_ret,
	bc_goto,
	bc_if,
	bc_repeat,
	bc_make_array,
	bc_fork,
	bc_yield,
};
@}
bc_lit - положить на стек содержимое следующую ячейку
bc_setq - принять со стека X и Y и положить в символ с адресом X Y
bc_drop - выкинуть элемент со стека
bc_decl - отметить символ в текущем scope(bc_setq присваивает там
  где отмечено, а не в текущем); адрес символа должен располагаться
  в следующей ячейке  
bc_scope_push, bc_scope_pop - создать и удалить scope
bc_defun - создать функцию в текущем scope; в следующей ячейке адрес символа с
  именем функции, безусловный переход на ячейку после функции, далее код функции, который завершается bc_ret
bc_ret - перейти по адресу из стека адресов
bc_goto - переход на ячейку с номером в следующей ячейке после bc_goto(именно номер, а не адрес)
bc_if - если на стеке не 0, то перейти через следующую ячейку,
  если 0, то перейти на ячейку с номером хранящемся в следующей ячейке
bc_repeat - избыточное слово, но думаю так будет быстрее. Берёт число N со стека и
  выполняет код(который начинается через ячейку) N раз. В следующей ячейке хранится номер ячейки
  куда будет выполнен переход, если N <= 0.
bc_make_array - создаёт массив из элементо, что хранится на стеке. Число элементов хранится в следующей
  ячейке, поэтому после создания нужно перейти через ячейку.
bc_fork - разбивает текущую задачу на две. Текущий продолжает выполняться перепрыгнув через N ячеек,
  N - хранится в следующей ячейки. Второй начинает с через ячейку.
  У второй задачи стек возвратов пуст, поэтому вызов bc_ret завершает его выполнение.
bc_yield - передаёт управление следующей задаче

Компиляция в байткод:
@d danmakufu_bytecode.c functions @{
intptr_t *danmakufu_compile_to_bytecode(const AstCons *cons) {
	intptr_t *code = malloc(sizeof(intptr_t)*DANMAKUFU_BYTECODE_MAXSIZE);
	if(code == NULL) {
		fprintf(stderr, "\nCan't allocate memory for bytecode\n");
		exit(1);
	}

	int pos = 0;
	danmakufu_compile_to_bytecode_helper(cons, code, &pos);

	return code;
}
@}

@d danmakufu_bytecode.h prototypes @{
intptr_t *danmakufu_compile_to_bytecode(const AstCons *cons);
@}

Максимальный размер буфера для байткода:
@d danmakufu_bytecode.c structs @{
#define DANMAKUFU_BYTECODE_MAXSIZE 65536
@}

@d danmakufu_bytecode.c functions @{
static void danmakufu_compile_to_bytecode_helper(const void *obj, intptr_t *code, int *pos) {
	if(obj == NULL) {
		fprintf(stderr, "\ndanmakufu_compile_to_bytecode_helper: NIL\n");
		exit(1);
	}

	switch(((const AstCons*)obj)->type) {
		case ast_cons: {
			const AstCons *p = obj;
			switch(car(p)) {
				@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons@>
			}
			break;
		}
		case ast_symbol: {
			const AstSymbol *symb = obj;
			printf("%s", symb->name);
			break;
		}
		case ast_string: {
			const AstString *str = obj;
			printf("\"%s\"", str->str);
			break;
		}
		case ast_character: {
			const AstString *chr = obj;
			printf("'%s'", chr->str);
			break;
		}
		case ast_number: {
			const AstNumber *num = obj;
			printf("%f", num->number);
			break;
		}
		default:
			fprintf(stderr, "\ndanmakufu_compile_to_bytecode_helper: unknown object\n");
			exit(1);
			break;
	}
}
@}

Если встретили progn:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_progn:
	if(cdr(p) == NULL) {
		fprintf(stderr, "\nprogn without args\n");
		exit(1);
	}
	for(AstCons *s = cdr(p); cdr(s) != NULL; s = cdr(s)) {
		danmakufu_compile_to_bytecode_helper(s, code, pos);
		code[*pos++] = bc_drop;
	}

	danmakufu_compile_to_bytecode_helper(s, code, pos);

	break;
@}
можно запоминать глубину стека, но пока(для простоты) сделано из
  предположения, что функция возвращает всегда один параметр.
Выкидываем один элемент со стека после вызова, кроме последнего.
FIXME: на самом деле, многие вообще ничего не возвращают(пока),
  поэтому в vm надо временно отключить bc_drop для тестирования.

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_defvar:
	if(cdr(p) == NULL || cddr(p) == NULL) {
		fprintf(stderr, "\ndefvar without args\n");
		exit(1);
	}

	if(cadr(p)->type != ast_symbol) {
		fprintf(stderr, "\ndefvar: not symbol\n");
		exit(1);
	}

	danmakufu_compile_to_bytecode_helper(cddr(p), code, pos);
	code[*pos++] = bc_lit;
	code[*pos++] = cadr(p);
	code[*pos++] = bc_setq;
	break;
@}

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_defscriptmain:
	// cadr(p) contains type of scriptmain
	if(cdr(p) == NULL || cddr(p) == NULL) {
		fprintf(stderr, "\ndefscriptmain without args\n");
		exit(1);
	}
	code[*pos++] = bc_scope_push;
	danmakufu_compile_to_bytecode_helper(cddr(p), code, pos);
	code[*pos++] = bc_scope_pop;
	break;
@}
не учитываем тип скрипта, так как я не знаю зачем он :(

Вызов функции:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_funcall:
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\nfuncall without args\n");
		exit(1);
	}
	for(AstCons *s = cddr(p); s != NULL; s = cdr(s))
		danmakufu_compile_to_bytecode_helper(car(s), code, pos);
	code[*pos++] = cadr(p);
	break;
@}

Создание символа в scope и необязательное присваивание:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_implet:
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\nimplet without args\n");
		exit(1);
	}

	if(cadr(p)->type != ast_symbol) {
		fprintf(stderr, "\nimplet: not symbol\n");
		exit(1);
	}

	code[*pos++] = bc_decl;
	code[*pos++] = cadr(p);

	if(cddr(p) != NULL) {
		danmakufu_compile_to_bytecode_helper(cddr(p), code, pos);

		code[*pos++] = bc_lit;
		code[*pos++] = cadr(p);
		code[*pos++] = bc_setq;
	}
	break;
@}

Выйти из цикла:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_break: {

	code[*pos++] = bc_goto;

	code[*pos++] = last_break;
	last_break = *pos-1;

	break;
}
@}
break выходит из цикла, но в какую точку кода делать goto?
Любая сущность, которая допускает использования break, должна
  запоминать старое значение last_break, затем присваивать ему 0;
  в конце нужно восстановить значение last_break.
При компиляции break, вместо адресов перехода goto запоминается позиция
  прошлого break, те создаётся список.
@d danmakufu_bytecode.c structs @{
static int last_break;
@}

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_break @{
int old_last_break = last_break;
last_break = 0;
@}

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_break @{
while(last_break != 0) {
	int i = code[last_break];
	code[last_break] = *pos;
	last_break = i;
}

last_break = old_last_break;
@}



Возврат из блока:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_return: {
	if(cdr(p) != NULL)
		danmakufu_compile_to_bytecode_helper(cdr(p), code, pos);

	code[*pos++] = bc_goto;

	code[*pos++] = last_return;
	last_return = *pos-1;

	break;
}
@}
так как мы ещё не знаем в какую точку переходить при вызове return,
  то введём специальный список точек возрата: в первом неизвестном
  return будет 0, а следующие будут указывать на этот с помощью переменной:
@d danmakufu_bytecode.c structs @{
static int last_return;
@}
при объявлении блока, её будут устанавливать в 0, а return будет переопределять её
на себя. После завершения блока переменной нужно вернуть старое значение; вдруг
я буду лямбды делать.

Объявление функции:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_defun: {
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\ndefun without args\n");
		exit(1);
	}

	@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper defun@>

	break;
}
@}

Команда на создание функции, имя функции, команда перехода,
зарезервированная ячейка для перехода на неё и команда создания скопа:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper defun @{
code[*pos++] = bc_defun;
code[*pos++] = cadr(p);
code[*pos++] = bc_goto;

int for_goto = *pos;
code[*pos++] = 0;

@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_return@>

code[*pos++] = bc_scope_push;
@}
goto нужен, чтобы при объявлении функции не выполнять её тело.

Для коректной работы return сохраним старое значение last_return, и
присвоим ему 0:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_return @{
int old_last_return = last_return;
last_return = 0;
@}

Из-за стека придётся перевернуть параметры местами. Пересчитаем количество
ячеек необходимое для параметров:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper defun @{
int reserv = 0;

for(const AstCons *s = car(cddr(p)); s != NULL; s = cdr(s)) {
	if(car(s)->type == ast_symbol)
		reserv += 3;
	else if(car(s)->type == ast_cons && caar(s) == ast_implet)
		reserv += 5;
	else {
		fprintf(stderr, "\ndefun incorrect args\n");
		exit(1);
	}
}
@}

Скомпилируем параметры в зависимости от их вида:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper defun @{
*pos += reserv;

for(const AstCons *s = car(cddr(p)); s != NULL; s = cdr(s)) {
	if(car(s)->type == ast_symbol) {
		*pos -= 3;
		code[*pos] = bc_lit;
		code[*pos+1] = car(s);
		code[*pos+2] = bc_setq;
	} else if(car(s)->type == ast_cons && caar(s) == ast_implet) {
		*pos -= 5;
		code[*pos] = bc_decl;
		code[*pos+1] = car(cadr(s));

		code[*pos+2] = bc_lit;
		code[*pos+3] = car(s);
		code[*pos+4] = bc_setq;
	}
}

*pos += reserv;
@}

Скомпилируем тело функции, закроем скоп, запишем команду выхода из функции
и заполним ячейку после bc_goto:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper defun @{
danmakufu_compile_to_bytecode_helper(cdr(cddr(p)), code, pos);

@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_return@>

code[*pos++] = bc_scope_pop;
code[*pos++] = bc_ret;

code[for_goto] = *pos;
@}

Восстановим last_return и заполним все return'ы значением pos:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_return @{
while(last_return != 0) {
	int i = code[last_return];
	code[last_return] = *pos;
	last_return = i;
}

last_return = old_last_return;
@}


Условный оператор if:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_if: {
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\nif without args\n");
		exit(1);
	}

	danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

	code[*pos++] = bc_if;

	int for_if = *pos;
	code[*pos++] = 0;

	danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);

	code[for_if] = *pos;

	if(cdr(cddr(p)) != NULL) {
		code[*pos++] = bc_goto;
		int for_else = *pos;
		code[*pos++] = 0;

		danmakufu_compile_to_bytecode_helper(cdr(cddr(p)), code, pos);

		code[for_else] = *pos;
	}

	break;
}
@}

Оператор цикла loop:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_loop: {
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\nloop without args\n");
		exit(1);
	}

	danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

	code[*pos++] = bc_repeat;

	int for_loop = *pos;
	code[*pos++] = 0;

	danmakufu_compile_to_bytecode_helper(cddr(p), code, pos);

	code[for_loop] = *pos;

	break;
}
@}

Оператор цикла while:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_while: {
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\nwhile without args\n");
		exit(1);
	}

	int for_begin = *pos;
	danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

	code[*pos++] = bc_if;

	int for_while = *pos;
	code[*pos++] = 0;

	danmakufu_compile_to_bytecode_helper(cddr(p), code, pos);

	code[*pos++] = bc_goto
	code[*pos++] = for_begin;

	code[for_while] = *pos;

	break;
}
@}

Оператор присваивания setq:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_setq: {
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\nsetq without args\n");
		exit(1);
	}

	code[*pos++] = bc_lit;
	code[*pos++] = cadr(p);
	code[*pos++] = bc_setq;

	break;
}
@}

Оператор создания массива:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_make_array: {
	int num_el = 0;

	if(cdr(p) != NULL && car(cadr(p)) == ast_list)
		for(const AstCons *s = cdr(cadr(p)); s != NULL; s = cdr(s)) {
			danmakufu_compile_to_bytecode_helper(car(s), code, pos);
			num_el++;
		}
	else if(cdr(p) != NULL) {
		fprintf(stderr, "\nmake-array incorrect args\n");
		exit(1);
	}

	code[*pos++] = bc_make_array;
	code[*pos++] = num_el;

	break;
}
@}


@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
case ast_taskcall: {
	if(cdr(p) == NULL || cadr(p) == NULL) {
		fprintf(stderr, "\nsetq without args\n");
		exit(1);
	}

	code[*pos++] = bc_fork;

	int for_taskcall = *pos;
	code[*pos++] = 0;

	for(AstCons *s = cddr(p); s != NULL; s = cdr(s))
		danmakufu_compile_to_bytecode_helper(car(s), code, pos);

	code[*pos++] = cadr(p);

	code[for_taskcall] = *pos - for_taskcall;
}
@}

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
@d player_move_to animation block @{@-
if(move_to == player_move_to_left)
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

@d Player private structs @{@-
static int player_move_horizontal;
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
				id = image_load("reimu.png");

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

@d player_draw fly to forward @{@-
if(player_movement_animation > 300)
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
@d player_draw fly to left @{@-
if(last_toward != -1)
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

@d player_draw fly to right @{@-
if(last_toward != 1)
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

@d player_bonus_line players @{@-
case player_reimu:
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
@d Bullet private structs @{@-
static BulletList *pool;

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
		id = image_load("bullet_green.png");

	image_draw_center(id,
		GAME_FIELD_X + bullet->x,
		GAME_FIELD_Y + bullet->y,
		bullet->angle+90, 0.3);
}

static void bullet_red_draw(BulletList *bullet) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_green.png");

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
@d Bullet types @{@-
bullet_reimu_first,
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
@d bullets_action other bullets @{@-
case bullet_reimu_first:
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
		id = image_load("bullet_white_card.png");

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
//		if(bullet->bullet_type == bullet_red)
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
//	glClearColor(0, 0, 0, 0);
//	glClear(/*GL_COLOR_BUFFER_BIT |*/ GL_DEPTH_BUFFER_BIT);

//	glDisable(GL_TEXTURE_2D);
//	glEnable(GL_DEPTH_TEST);

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
		id = image_load("forest.png");

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
@d background_draw sync forest @{@-
if(background_time_points > 2) {
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
@d background_draw calculate shiftx @{@-
else if(background_animation >= 180 && background_animation < 460)
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
//	glScalef(scale, scale, 0);

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
		tree_id[0] = image_load("tree1.png");
	if(tree_id[1] == -1)
		tree_id[1] = image_load("tree2.png");
	if(tree_id[2] == -1)
		tree_id[2] = image_load("tree3.png");
	if(tree_id[3] == -1)
		tree_id[3] = image_load("tree4.png");

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

@d background_draw OGL trees @{@-
glPushMatrix();
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
@d Bonus private structs @{@-
static BonusList *pool;

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

@d Bonus public prototypes @{@-
void bonus_small_score_create(int x, int y);
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

@d Bonus private prototypes @{@-
static BonusList *bonus_get_free_cell(void);
@}

Поведение бонусов:

@d Bonus public prototypes @{@-
void bonuses_action(void);
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
@d Bonuses params @{@-
int move_percent;
int move_step;
@}
move_percent - процент пути который осталось пройти. В конце пути равен 0.
move_step - тип совершаемого действия, нужен для совершения сложного движения.

При создании бонуса нужно обнулять оба параметра move_percent и move_step.
@d bonus_power_action move up @{@-
if(bonus->move_step == 0) {
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

@d Bonus public prototypes @{@-
void bonuses_update_all_time_points(void);
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

@d Bonus private prototypes @{@-
static void bonus_move_to(BonusList *bonus, int x, int y);
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

@d Bonus private prototypes @{@-
static void bonus_move_to_slower(BonusList *bonus, int x, int y);
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

@d Bonus private prototypes @{@-
static void bonus_move_to_direction(BonusList *bonus, int move_to);
@}

@d Bonus private structs @{
enum {
	bonus_move_to_left, bonus_move_to_right, bonus_move_to_up, bonus_move_to_down
};
@}


@d Bonus public prototypes @{@-
void bonuses_draw(void);
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
		id = image_load("bonus_small_score.png");

	image_draw_center(id,
		GAME_FIELD_X + bonus->x,
		GAME_FIELD_Y + bonus->y,
		0, 0.3);
}

static void bonus_medium_score_draw(BonusList *bonus) {
	static int id = -1;

	if(id == -1)
		id = image_load("bonus_medium_score.png");

	image_draw_center(id,
		GAME_FIELD_X + bonus->x,
		GAME_FIELD_Y + bonus->y,
		0, 0.3);
}

static void bonus_power_draw(BonusList *bonus) {
	static int id = -1;

	if(id == -1)
		id = image_load("bonuses.png");

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
@d Bonus public prototypes @{@-
void get_visible_bonuses(void);
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
@d Bonus public prototypes @{@-
void move_visible_bonuses(void);
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

@d Bonuses params @{@-
int move_to_player;
@}
Флаг нужно обнулять в конструкторе и обрабатывать в функции движения(i.e.:bonuses_action),
когда move_to_player установлен, то move_step начинает использоваться особым образом, об этом
ниже. Поэтому следует обнулять move_step при установке move_to_player.

Реализация для бонуса дающего очки:
@d get_visible_bonuses all other bonuses' gets @{@-
case bonus_small_score:
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
@d get_visible_bonuses all other bonuses' gets @{@-
case bonus_power:
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
@d bonus_power_action move to player @{@-
if(bonus->move_to_player == 1) {
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
}
@}

@d Dlist public prototypes @{
//DList *dlist_create_pool(int num, size_t size);
@}


Выделяет элемент из пула pool и возвращает его. Если список dlist != NULL, то
	возвращённый элемент будет перед dlist.
@d Dlist functions @{
DList *dlist_alloc(DList *dlist, DList **pool) {
	DList *p;

	if(pool == NULL) {
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

@d Dlist public prototypes @{@-
DList *dlist_alloc(DList *dlist, DList **pool);
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

@d Dlist public prototypes @{@-
void dlist_free(DList *el, DList **pool);
@}


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
X_init - аллоцируется слотов в самом начале
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
@d load_font maybe font was loaded @{@-
{
	int i;
	for(i=0; i < font_list_pos; i++)
		if(!strcmp(font_list[i].filename, filename))
			return i;
}
@}

@d load_font else load font @{@-
{
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

@d load_font check font_list_pos @{@-
if(font_list_pos == FONT_LIST_LEN) {
	fprintf(stderr, "\nFont list full\n");
	exit(1);
}
@}

@d load_font copy filename @{@-
strncpy(font->filename, filename, FONT_FILE_NAME_SIZE);
font->filename[FONT_FILE_NAME_SIZE-1] = '\0';
@}

@d load_font load image @{@-
{
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

@d load_font load chars' struct @{@-
{
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
@d Font public prototypes @{@-
void print_text(const char *str, int x, int y, int w, int color, int fd);
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
@d Font public prototypes @{@-
int pos_last_word_of_long_string(const char *str, int w, int fd);
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
@d dialog_msg find char, set pointers and get i @{@-
for(i = 0; i < left_side_point; i++)
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
@d dialog_msg set side @{@-
{
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
@d dialog_msg set other_side @{@-
for(i = 0; i < *other_side_point; i++)
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
@d dialog_action check dialog_mode flag @{@-
if(dialog_mode == 0)
	return;
@}

Очки анимации появления и исчезновения окна диалога и персонажей:
@d dialog_action dialog open & close animation @{@-
if(anim_point == 0) {
	switch(anim_mode) {
		@<dialog_action anim_mode == 1@>
		@<dialog_action anim_mode == 2@>
	}
	anim_point = 70;
}
@}

@d Dialog private structs @{@-
static int anim_point;
@}

Появление диалога:
@d dialog_action anim_mode == 1 @{@-
case 1:
	if(anim_step < 100)
		anim_step++;
	else
		anim_mode = 0;
	break;
@}
Изначально anim_step = 0.

Исчезновение диалога:
@d dialog_action anim_mode == 2 @{@-
case 2:
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
@d dialog_action move characters @{@-
if(character_move_point == 0) {
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

@d Dialog private structs @{@-
static int character_move_point;
@}
Счётчик используемый при перемещении персонажей в диалоге. Когда
	он равен 0, картинки сдвигаются.

Добавляем единицу к счётчику выводимых букв:
@d dialog_action set message_point @{@-
if(message_point_point == 0) {
	if(message_point < message_len && more_flag == 0)
		message_point++;

	message_point_point = 40;
}
@}

@d Dialog private structs @{@-
static int message_point_point;
@}
Счётчик используемый при увеличении числа букв, которые выводятся в окне
	диалога. Когда он равен 0, выводится следующая буква.

@d Dialog public prototypes @{@-
void dialog_action(void);
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

@d Dialog public prototypes @{@-
void dialog_update_all_time_points(void);
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

@d Dialog public prototypes @{@-
void dialog_draw(void);
@}

Выводим задник с учётом анимации появления и исчезновения:
@d dialog_draw draw background @{@-
{
	static int id = -1;

	if(id == -1)
		id = image_load("dialog.png");

	image_draw_corner(id, 20, 650 - anim_step*2, 0, 0, 256, 66, 1.9f, color_white);
}
@}

Выводим символы по одному, учитываем строки, если надо пишем more...:
@d dialog_draw draw characters @{@-
{
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
@d dialog_draw draw characters step by step @{@-
{
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
@d dialog_draw draw characters in line @{@-
{
	char b;
	b = message[new_pos];
	message[new_pos] = '\0';
	
	@<dialog_draw print more... or message@>
	
	message[new_pos] = b;
}
@}
Не забываем восстановить затёртый символ.

Выводим more... или строку с учётом анимации:
@d dialog_draw print more... or message @{@-
more_flag = 0;
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

@d Dialog private structs @{@-
static int more_flag;
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

@d Dialog public prototypes @{@-
void dialog_next_page(void);
@}

Эту функцию вызывают, чтобы закончить диалог:
@d Dialog public prototypes @{@-
void dialog_end(void);
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
@d Dialog private prototypes @{@-
static void dialog_true_end(void);
@}

@d Dialog functions @{
static void dialog_true_end(void) {
	dialog_mode = 0;
	dialog_clear();
}
@}
После выполнения функции dialog_mode = dialog_says = anim_mode = 0.

Выводим персонажей:
@d dialog_draw draw chars @{@-
{
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

@d dialog_draw posx for left @{@-
int x = -180 + left[i].position + anim_step*2;
@}
В переменной x хранится смещения относительно левой стороны экрана.

@d dialog_draw posx for right @{@-
int x = 575 - right[i].position - anim_step*2;
@}


Выводим Рейму с левой стороны:
@d dialog_draw left side characters @{@-
case dialog_reimu: {
	static int normal = -1;
	static int angry = -1;

	if(normal == -1)
		normal = image_load("reimu_normal_l.png");

	if(angry == -1)
		angry = image_load("reimu_angry_l.png");


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
@d dialog_draw left side characters @{@-
case dialog_yukari: {
	static int normal = -1;

	if(normal == -1)
		normal = image_load("yukari_normal_l.png");

	image_draw_corner(normal, x, 250, 0, 0, 128, 256, 1.0f, color_white);
	break;
}
@}

@d Dialog other characters @{@-
dialog_yukari,@}

Выводим Марису с правой стороны:
@d dialog_draw right side characters @{@-
case dialog_marisa: {
	static int normal = -1;

	if(normal == -1)
		normal = image_load("marisa_normal_r.png");

	image_draw_corner(normal, x, 250, 0, 0, 128, 256, 1.0f, color_white);
	break;
}
@}

@d Dialog other characters @{@-
dialog_marisa,@}


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
		dialog = image_load("dialog.png");

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

@d panel_draw draw noise @{@-
{
	int i, j;

	@<panel_draw draw horizontal borders@>
	@<panel_draw draw vertical borders@>
	@<panel_draw draw bars@>
}
@}
Далее идут участки, которые нужно переписать после изменения GAME_FIELD_*, а всё благодаря
моей лени :(

Горизонтальные полоски сверху и снизу:
@d panel_draw draw horizontal borders @{@-
for(i = 0; i < 800; i+=58) {
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
@d panel_draw draw vertical borders @{@-
for(j = 0; j < 600; j+=29) {
	image_draw_corner(dialog, 0, j, 0, 116, 0+GAME_FIELD_X, 116+29, 1.0f, color_white);
	image_draw_corner(dialog, 58*8+56, j, 56, 116, 0+58, 116+29, 1.0f, color_white);
}
@}
См. про горизрнтальные полосы выше.
58*8 = 464, а GAME_FIELD_X+GAME_FIELD_W = 520, те 520-464 = 56 и надо
	нарисовать оставшиеся 2 пикселя.

Заполняем оставшееся место:
@d panel_draw draw bars @{@-
for(i = 58*9; i < 800; i+=58)
	for(j = 0; j < 600; j+=29)
		image_draw_corner(dialog, i, j, 0, 116, 0+58, 116+29, 1.0f, color_white);
@}

@d panel_draw draw road @{@-
image_draw_corner(dialog, 630, 250, 100, 85, 100+56, 85+161, 2.0f, color_white);
@}

@d panel_draw draw moon @{@-
image_draw_corner(dialog, 625, 370, 2, 155, 98, 252, 1.0f, color_white);
@}

HiScore & Score:
@d panel_draw draw score @{@-
image_draw_corner(dialog, 540, 60, 167, 71, 167+77, 71+16, 1.0f, color_white);
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

@d panel_draw draw player & spell @{@-
image_draw_corner(dialog, 540, 140, 167, 117, 167+65, 117+21, 1.0f, color_white);
image_draw_corner(dialog, 540, 170, 167, 140, 167+49, 140+21, 1.0f, color_white);

{
	int i;

	for(i = 0; i < 6; i++)
		image_draw_corner(dialog, 630+22*i, 137, 1, 69, 1+32, 69+32, 0.7f, color_white);

	for(i = 0; i < 7; i++)
		image_draw_corner(dialog, 630+22*i, 167, 40, 68, 40+33, 68+33, 0.7f, color_white);
}
@}

@d panel_draw draw power,graze,point,time @{@-
image_draw_corner(dialog, 540, 220, 167, 160, 167+62, 160+19, 1.0f, color_white);
image_draw_corner(dialog, 540, 250, 168, 187, 168+57, 187+15, 1.0f, color_white);
image_draw_corner(dialog, 540, 280, 167, 209, 167+53, 209+16, 1.0f, color_white);
image_draw_corner(dialog, 540, 310, 167, 232, 167+50, 232+16, 1.0f, color_white);
@}

@d Panel public prototypes @{@-
void panel_draw(void);
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

/*	{
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

@d main variables @{@-
int fps = 0;
@}

Рисуем задник:
@d Draw backgrounds @{@-
background_draw();
@}

Отрисовка всех персонажей:
@d Draw characters @{@-
characters_draw();
@}

Отрисовка главного персонажа:
@d Draw player @{@-
player_draw();
@}

Отрисовка пуль:
@d Draw bullets @{@-
bullets_draw();
@}

Отрисовка бонусов:
@d Draw bonuses @{@-
bonuses_draw();
@}

Панель со статистикой:
@d Draw panel @{@-
panel_draw();
@}

Рисуем окно диалога:
@d Draw dialog @{@-
dialog_draw();
@}

@d Draw FPS @{@-
{
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


@d License @{@-
/*
 * danmaku
 * Copyright (C) 2011-2012 Iljasov Ramil
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
