

2010 28 июля
начинаю писать концепт даммаку



1)стараюсь делать по KISS
2)делаю тяпляп, лишь бы работало




Набор функция для работы с окном.

@o os_specific.h @{
@<Window functions prototypes@>
@<Image functions prototypes@>
@}



window_init вызывается один раз, где-то в начале функции main.
Ресурсы при закрытии чистить не буду :3

Этот кусок я не обдумывал, возможно набор функций не удачный :(

@d Window functions prototypes @{
void window_init(void);
void window_create(void);

void window_set_fullscreen(int flag);
int window_is_fullscreen(void);

void window_set_size(int w, int h);

void window_update(void);
@}

@o os_specific.c @{

#include <SDL.h>
#include <GL/gl.h>
#include <GL/glu.h>

#include <stdlib.h>

#include "os_specific.h"

static SDL_Surface *surface;



@<Window functions@>
@<Image functions@>

@}



@d Window functions @{

@<Window init function@>
@<Window create function@>
@<Window set size function@>
@<Functions for fullscreen@>
@<Window update function@>
@}

Эту функцию вызывают один раз, когда программа запускается:

@d Window init function @{
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

Эту функцию вызывают, когда окно нужно создать или после
изменения её характеристик:

@d Window create function @{
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

	@<OGL config@>

	return;
}
@}

w, h - размеры окна
game_w, game_h - размеры окна в игре, они будут растягиваться под w, h

Гастроим ogl для вывода 2D графики:

@d OGL config @{
glClearColor(0, 0, 0, 0);
glClear(GL_COLOR_BUFFER_BIT);

glEnable(GL_TEXTURE_2D);

@<OGL blend@>

glViewport(0, 0, w, h);

glMatrixMode(GL_PROJECTION);
glLoadIdentity();

glOrtho(0, game_w, game_h, 0, 0, 1);

glDisable(GL_DEPTH_TEST);

glMatrixMode(GL_MODELVIEW);
glLoadIdentity();
@}

Это нужно, чтобы у текстур была прозрачность:

@d OGL blend @{
glEnable(GL_BLEND);
glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
@}


Функция изменения размера окна:

@d Window set size function @{
void window_set_size(int w_, int h_) {
	w = w_;
	h = h_;

	window_create();
}
@}

Как видно window_create она запускает сама. Может кому-то и не нравятся мелькающие окна, а мне
пофиг.


Очень простые функции для работы с fullscreen:

@d Functions for fullscreen @{
void window_set_fullscreen(int flag) {
	fullscreen = flag;

	window_create();
}

int window_is_fullscreen() {
	return fullscreen;
}
@}

Эту фунцию вызывают когда уже все нарисовано в буфере:

@d Window update function @{
void window_update(void) {
	SDL_GL_SwapBuffers();
}
@}

Перейдём к функциям по работе с изображениями

image_load будет кроме возвращения дескриптора ещё сохранять имя файла для загрузки при изменении
размера окна

@d Image functions prototypes @{
/* принимает имя файла, возвращает дескриптор или -1 */
int image_load(char *filename);
void image_draw(int id, int x, int y, float rot, float scale);

int image_size_h(int id);
int image_size_w(int id);
@}


Так как нам придётся перегружать все рисунки, то мы будем их хранить в
массиве.
Для начала, почему массив? Этот массив похож на стек. Список рисунков всё равно не
имеет дыр, поэтому будем использовать этот достаточно простой вариант.
Кроме имен файлов там будут хранится старые surface, чтобы мы могли легко удалять их.
id который возвращает image_load и есть номер элемента в массиве.

@d Image functions @{

#include <SDL_image.h>

@<Struct for image list@>
@<load_from_file helper function@>
@<image_load function@>
@<image_draw function@>
@<image_size_w and image_size_h@>
@}

Опишем структуру в которой будет храниться список открытых изображений

@d Struct for image list @{
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


Функция загрузки изображения:

@d image_load function @{

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

		if((img->w & (img->w - 1)) != 0 ||
			(img->h & (img->h - 1)) != 0) {
			fprintf(stderr, "\nImage size isn't power of 2: %s\n", filename);
			exit(1);
		}

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

Теперь о вспомогательной функции подробнее:

@d load_from_file helper function @{
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

Функция вывода изображения:

@d image_draw function @{
void image_draw(int id, int x, int y, float rot, float scale) {
	ImageList *img = &image_list[id];

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	glBegin(GL_QUADS);
		glTexCoord2i(0, 0);
		//glVertex2i(0, 0);
		glVertex2i(-img->w/2, -img->h/2);

		glTexCoord2i(1, 0);
		//glVertex2i(img->w, 0);
		glVertex2i(img->w/2, -img->h/2);

		glTexCoord2i(1, 1);
		//glVertex2i(img->w, img->h);
		glVertex2i(img->w/2, img->h/2);

		glTexCoord2i(0, 1);
		//glVertex2i(0, img->h);
		glVertex2i(-img->w/2, img->h/2);
	glEnd();
}
@}

Очень простая функция. Я решил не делать списка картинок и использовать вместо
них директории с множеством файлов с картинками в них. Это позволит делать разные
картинки разного размера, что было бы трудно сделать для списка картинок.

Так как размеры разные то функций вывода две, одна выводит относительно края картинки,
а другая относительно центра. В этом месте представлена низкоуровневая функция, которая
выводит с края.


Иногда нам понадобится узнавать размеры изображений:
FIXME: Зачем понадобиться узнавать размеры?

@d image_size_w and image_size_h @{
int image_size_h(int id) {
	return image_list[id].h;
}

int image_size_w(int id) {
	return image_list[id].w;
}
@}

Они элементарны и не требуют пояснений.



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
	key_attack, key_move_left, key_move_right, key_move_up, key_move_down,
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
static int attack, move_left, move_right, move_up, move_down, escape;
@}

Здесь мы устанавливаем и сбрасываем флаги:

@d Get event @{
while(SDL_PollEvent(&event)) {
	int key = event.type == SDL_KEYDOWN;

	switch(event.key.keysym.sym) {
		case SDLK_SPACE:
			attack = key;
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
	case key_attack:
		return attack;
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
  ai - флаг, этот персонаж управляется компьютером
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

CharacterList characters[CHARACTER_LIST_LEN];
int characters_pos;

@<Character structs@>
@}


Перейдем к реализации функций.


Функции создания персонажей.

Типы персонажей:
@o characters.c @{
enum {
	character_reimu, character_marisa
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
	@<Reimu create function@>
}
@}

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
	}
}
@}

В этой функции используются функции character_set_weak_time_point_x и
character_set_weak_time_point_y. Они определяют тип персонажа cd и
вызывают специализированию функцию для каждого типа персонажа. Она устанавливает
значение для time_point_for_movement_to_x и time_point_for_movement_to_y
после того как было сделано перемещение.

Как видно, ход по x или y возможен только если соответствующий time_point равен нулю.


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
		default:
			fprintf(stderr, "\nUnknown character\n");
			exit(1);
	}
}

@}

Конкретные реализации функций обновления time_point:

@d Different characters set weak time_point functions @{
static void character_reimu_set_weak_time_point_x(int cd) {
	characters[cd].time_point_for_movement_to_x = 1;
}

static void character_reimu_set_weak_time_point_y(int cd) {
	characters[cd].time_point_for_movement_to_y = 1;
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
	@<Is end of movement?@>
	@<Coef calculation@>
	@<Choose direction@>
}
@}

@d character_move_to_point params @{
int dx = character->x - x;
int dy = character->y - y;
@}

dx, dy - разница между текущими координатами и конечной точкой.

Если они равны нулю, то мы достигли конечной точки:

@d Is end of movement? @{
if(dx == 0 && dy == 0) {
	character->move_flag = 0;
	return;
}
@}

Мы не забыли установить флаг движения move_flag в 0. Движения больше нет.

Добавим к структуре этот флаг:

@d Character struct param @{
int move_flag;
float move_coef;
@}

Кроме него мы добавили move_coef так как нам придётся так или иначе хранить начальную точку
маршрута. move_coef это dx/dy при начале движения.

Запишем присваивание этого коэффициента:

@d Coef calculation @{
if(dy == 0)
	k = 100.0;
else
	k = fabs((float)dx/(float)dy);

if(character->move_flag == 0) {
	character->move_flag = 1;
	character->move_coef = k;
}
@}

Вначале мы считаем значение k=dx/dy, оно нам пригодится позже, если движение только начато(move_flag = 0),
то присваиваем этот коэффициент.

@d character_move_to_point params @{
float k;
@}

этот коэффициет равен tg(alpha) = dx/dy, с помощью него мы можем выбрать направление движения:

@d Choose direction @{
if(k < character->move_coef)
	fy = 1;
else if(k > character->move_coef)
	fx = 1;
else {
	fx = 1;
	fy = 1;
}

if(fx == 1 && dx != 0) {
	if(dx > 0)
		character_move_to(cd, character_move_to_left);
	else
		character_move_to(cd, character_move_to_right);
}

if(fy == 1 && dy != 0) {
	if(dy > 0)
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

@d Reimu create function @{
character->step_of_movement = 0;
@}

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

if(character->move_flag == 0) {
	character->step_of_movement++;
}
@}

Перемещаемся между точками.

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
			default:
				fprintf(stderr, "\nUnknown character\n");
				exit(1);
		}
}
@}

Конкретные функции рисования для различных персонажей:

@d Draw functions for different characters @{
static void character_reimu_draw(int cd) {
	static int id = -1;

	if(id == -1)
		id = image_load("aya.png");

	image_draw(id, characters[cd].x, characters[cd].y, 0, 0.1);
}

static void character_marisa_draw(int cd) {
	static int id = -1;

	if(id == -1)
		id = image_load("marisa.png");

	image_draw(id, characters[cd].x, characters[cd].y, 0, 1);
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


===========================================================

Пули.

@o bullets.h @{
@<Bullet types@>
@<Bullet functions prototypes@>
@}

@o bullets.c @{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "bullets.h"
#include "os_specific.h"

@<Bullet macros@>
@<Bullet structs@>
@<Bullet functions@>
@}

Структура для хранения пуль:

@d Bullet structs @{
typedef struct {
	int x;
	int y;
	float angle;
	int bullet_type;
	int kill_me;
	@<Bullet params@>
} BulletList;
@}

x, y - коодинаты пули
angle - угол поворота
bullet_type - тип
kill_me - удалить пулю при попытке следующей вырисовки или перемещения

Стек пуль:

@d Bullet structs @{
static BulletList bullets[BULLET_LIST_LEN];
static int bullets_pos;
@}

BULLET_LIST_LEN - максимальное количество пуль

@d Bullet macros @{
#define BULLET_LIST_LEN 2048
@}

Функции создания пули не возвращают дескриптор. Пуля сразу начинает дейчтвовать после
создания.

@d Bullet functions prototypes @{
void bullet_create(int bullet_type, int x, int y, float angle);
@}

Типы пуль:

@d Bullet types @{
enum {
	bullet_white, bullet_red
};
@}

@d Bullet functions @{
@<Different bullet create functions@>

void bullet_create(int bullet_type, int x, int y, float angle) {
	if(bullets_pos == BULLET_LIST_LEN) {
		fprintf(stderr, "\nBullet list full\n");
		exit(1);
	}

	switch(bullet_type) {
		case bullet_white:
			bullet_white_create(bullets_pos, x, y, angle);
			break;
		case bullet_red:
			bullet_red_create(bullets_pos, x, y, angle);
			break;
		default:
			fprintf(stderr, "\nUnknown bullet\n");
			exit(1);
	}

	bullets_pos++;
}
@}

@d Different bullet create functions @{
static void bullet_white_create(int bullets_pos, int x, int y, float angle) {
	BulletList *bullet = &bullets[bullets_pos];

	bullet->x = x;
	bullet->y = y;
	bullet->angle = angle;
	bullet->bullet_type = bullet_white;
	@<Bullet create@>
}

static void bullet_red_create(int bullets_pos, int x, int y, float angle) {
	BulletList *bullet = &bullets[bullets_pos];

	bullet->x = x;
	bullet->y = y;
	bullet->angle = angle;
	bullet->bullet_type = bullet_red;
	@<Bullet create@>
}
@}

AI пуль:

@d Bullet functions prototypes @{
void bullets_action(void);
@}

@d Bullet functions @{
@<Bullet action helpers@>
@<Bullet actions@>

void bullets_action(void) {
	int i;

	for(i = 0; i < bullets_pos; i++) {
		BulletList *bullet = &bullets[i];

		@<Kill bullet if need@>

		switch(bullet->bullet_type) {
			case bullet_white:
				bullet_white_action(i);
				break;
			case bullet_red:
				bullet_red_action(i);
				break;
			default:
				fprintf(stderr, "\nUnknown bullet\n");
				exit(1);
		}
	}
}
@}

Если пуля отмечена для удаления, то удалим её. При этом bullet указывает на
ту же ячейку, что и раньше. bullet_delete - помещает туда ещё не обработаную пулю,
она тоже может быть помеченой к удалению, поэтому мы уменьшаем i и повторяем цикл.
bullet_delete декрементирует bullets_pos, но этот побочный эффект не должен повлиять,
если только не вмешается оптимизатор.

@d Kill bullet if need @{
if(bullet->kill_me == 1) {
	bullet_delete(i);
	i--;
	continue;
}
@}

если последняя пуля будет отмечена как удаленная, то станет i = -1, а bullets_pos = 0.
Начнется цикл и i увеличится на 1 => i = 0 и цикл завершится.

Функция удаления пули:

@d Bullet action helpers @{
static void bullet_delete(int bd) {
	bullets_pos--;

	bullets[bd] = bullets[bullets_pos];
}
@}

Удаленная пуля исчезает, её место занимает последняя в списке.

Конкретые функции действия пуль:

@d Bullet actions @{
static void bullet_white_action(int bd) {
	BulletList *bullet = &bullets[bd];

	bullet_move_to_angle_and_radius(bd, bullet->angle, 10.0);

	if(bullet->move_flag == 0)
		bullet->angle += 5;
}

static void bullet_red_action(int bd) {
	BulletList *bullet = &bullets[bd];

	bullet_move_to_angle_and_radius(bd, bullet->angle, 1000.0);
}
@}

bullet_move_to_angle - переместить пулю по направлению angel на радиус radius. Когда
пуля достигнет цели, то move_flag сброситься в 0.

Белая пуля делает круги, а красная улетает за край экрана по прямой.

Сложные пули делаются так: мы создаем "главную" пулю, которая создаёт "дочерние"
и сама удаляется(всегда). Весь "танец" делает ai дочерних пуль.
Не стоит забывать, что у пуль нет дескрипторов.


@d Bullet params @{
int move_flag;
float move_coef;
int move_x;
int move_y;
@}

move_flag - устанавливается в 0, если движение окончено. При начале движения этот флаг проверяется и
если он установлен, то продолжается старое движение. То есть чтобы начать новое движение нужно вначале
установить move_flag в 0, иначе будет продолжаться старое движение.

@d Bullet create @{
bullet->move_flag = 0;
@}

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

@d Bullet structs @{
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

@d Bullet structs @{
enum {
	bullet_move_to_left, bullet_move_to_right, bullet_move_to_up, bullet_move_to_down
};

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

@d Bullet structs @{
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

@d Bullet structs @{
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
	bullets[bd].time_point_for_movement_to_x = 1;
}

static void bullet_red_set_weak_time_point_y(int bd) {
	bullets[bd].time_point_for_movement_to_y = 1;
}
@}

Функция восстановления time points:

@d Bullet functions prototypes @{
void bullets_update_all_time_points(void);
@}

@d Bullet functions @{
void bullets_update_all_time_points(void) {
	int i;

	for(i = 0; i < bullets_pos; i++)
		switch(bullets[i].bullet_type) {
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
@}

Функции восстановления для конкретных пуль:

@d Bullet structs @{
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

@d Bullet functions prototypes @{
void bullets_draw(void);
@}

@d Bullet functions @{
void bullets_draw(void) {
	int i;

	for(i = 0; i < bullets_pos; i++)
		switch(bullets[i].bullet_type) {
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
@}

Рисуем конкретные:

@d Bullet structs @{
static void bullet_white_draw(int bd);
static void bullet_red_draw(int bd);
@}

@d Bullet functions @{
static void bullet_white_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_green.png");

	image_draw(id, bullets[bd].x, bullets[bd].y, bullets[bd].angle+90, 0.3);
}

static void bullet_red_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_green.png");

	image_draw(id, bullets[bd].x, bullets[bd].y, 0, 1);
}
@}

У пуль спрайт повёрнут на 90 градусов, исправляем.

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
передаёт хитбоксы пурсоныжей внутрь функции проверки пересечения пули,
фукнция пересечения возвращает истину или ложь, мы проверяем особые случаи повреждения и
отнимаем у персонажа сколько нужно жизней:
@d damage_calculate body @{
int i, j;

for(i = 0; i < characters_pos; i++) {
	CharacterList *character = &characters[i];

	if(character->is_sleep == 0)
		for(j = 0; j < bullets_pos; j++) {
			BulletList *bullet = &bullets[j];

			@<damage_calculate character and bullet team check@>
			@<damage_calculate collision check@>
			@<damage_calculate character's damage unique@>
		}

	@<damage_calculate if hp<0 then character died@>
}
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
switch(character->type) {
/*
	case character_reimu:
		if(bullet->type == bullet_white)
			character->hp -= 100000;
		break;
*/
	default:
		character->hp = 0;
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

TODO: дописать bullet_collide
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
пуль. Заведем счетчик действий step_of_movement, а вместо move_flag будем использовать
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

#include "os_specific.h"
#include "event.h"
#include "collision.h"
#include "characters.h"
#include "bullets.h"
#include "timers.h"

@<Main functions@>
@}


Функция main:

@d Main functions @{

int main(void) {
	window_init();
	window_create();

	enum {
		main_character_player,
	};

	character_reimu_create(main_character_player);
	characters[main_character_player].ai = 1;
	characters[main_character_player].is_sleep = 0;
	characters_pos = main_character_player + 1;

	{
		int i, j;
		for(i=0; i<10; i++)
			for(j=0; j<10; j++)
				bullet_create(bullet_white, 100+i*10, 100+j*10, 0);
	}

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

	@<Draw characters@>
	@<Draw bullets@>
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
	bullets_update_all_time_points();
}
@}
Функции characters_update_all_time_points и bullets_update_all_time_points вызываются раз в ~1 мс.


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
	character_move_to(main_character_player, character_move_to_left);
else if(is_keydown(key_move_right))
	character_move_to(main_character_player, character_move_to_right);

if(is_keydown(key_move_up))
	character_move_to(main_character_player, character_move_to_up);
else if(is_keydown(key_move_down))
	character_move_to(main_character_player, character_move_to_down);
@}

Кнопки влево, вправо и вверх, вниз разделены, чтобы была возможность перемещаться по диагонали.



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