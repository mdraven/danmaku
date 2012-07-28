
===========================================================

Компиляция в байткод для danmakufu


@o danmakufu_bytecode.h @{
@<License@>

#include <stdint.h>

#include "ast.h"

@<danmakufu_bytecode.h structs@>
@<danmakufu_bytecode.h prototypes@>
@}

@o danmakufu_bytecode.c @{
@<License@>

#include <stdlib.h>
#include <stdio.h>

#include "danmakufu_bytecode.h"

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
    bc_2drop,
    bc_dup,
    bc_2dup,
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
    bc_inc,
    bc_dec,
};
@}
bc_lit - положить на стек содержимое следующей ячейки
bc_setq - принять со стека X и Y и положить в символ с адресом X Y
bc_drop, bc_2drop - выкинуть элемент со стека
bc_decl - отметить символ в текущем scope(bc_setq присваивает там
  где отмечено, а не в текущем); адрес символа должен располагаться
  в следующей ячейке

bc_scope_push, bc_scope_pop - создать и удалить слой скопа(прошлые слои доступны);
  используется в while, if итд
TODO: сейчас что-то вроде динамической видимости, если нужна статическая, то
  при вызове слова(функция или переменная) нужны не одно число(номер символа), а
  два(ещё и номер скопа). Кроме того посмотреть комит "it was bad idea".

bc_defun - создать функцию в отмеченном scope; в следующей ячейке адрес символа с
  именем функции, номер ячейки после функции, далее код функции, который завершается bc_ret.
  Раньше тут было написано, что функция создаётся в текущем scope, но как тогда запустить
  @Bla? Ведь когда мы это делаем, скоп, в котором @Bla был объявлен - закрыт.
bc_ret - перейти по адресу из стека адресов
bc_goto - переход на ячейку с номером в следующей ячейке после bc_goto(именно номер, а не адрес)
bc_if - если на стеке не 0, то перейти через следующую ячейку,
  если 0, то перейти на ячейку с номером хранящемся в следующей ячейке
bc_repeat - избыточное слово, но думаю так будет быстрее. Берёт число N со стека и
  выполняет код(который начинается через ячейку) N раз. В следующей ячейке хранится номер ячейки
  куда будет выполнен переход, если N <= 0.
bc_make_array - создаёт массив из элементов, что хранится на стеке. Число элементов хранится в следующей
  ячейке, поэтому после создания нужно перейти через ячейку.
bc_fork - разбивает текущую задачу на две. Текущий продолжает выполняться перепрыгнув через N ячеек,
  N - хранится в следующей ячейки. Второй начинает с через ячейку.
  У второй задачи стек возвратов пуст, поэтому вызов bc_ret завершает его выполнение.
  Копируется скоп и стек данных.
bc_yield - передаёт управление следующей задаче
bc_dup - дублировать элемент на стеке
bc_inc, bc_dec - инкрементировать, декрементировать элемент на стеке

Компиляция в байткод:
@d danmakufu_bytecode.c functions @{
intptr_t *danmakufu_compile_to_bytecode(AstCons *cons, int *size) {
    intptr_t *code = malloc(sizeof(intptr_t)*DANMAKUFU_BYTECODE_MAXSIZE);
    if(code == NULL) {
        fprintf(stderr, "\nCan't allocate memory for bytecode\n");
        exit(1);
    }

    int pos = 0;
    danmakufu_compile_to_bytecode_helper(cons, code, &pos);

    *size = pos;

    return code;
}
@}
через size возвращается размер байткода

@d danmakufu_bytecode.h prototypes @{
intptr_t *danmakufu_compile_to_bytecode(AstCons *cons, int *size);
@}

Максимальный размер буфера для байткода:
@d danmakufu_bytecode.c structs @{
#define DANMAKUFU_BYTECODE_MAXSIZE 120000
@}
FIXME: переполнение буфера!

@d danmakufu_bytecode.c prototypes @{
static void danmakufu_compile_to_bytecode_helper(void *obj, intptr_t *code, int *pos);
@}

@d danmakufu_bytecode.c functions @{
static void danmakufu_compile_to_bytecode_helper(void *obj, intptr_t *code, int *pos) {
    if(obj == NULL) {
        fprintf(stderr, "\ndanmakufu_compile_to_bytecode_helper: NIL\n");
        exit(1);
    }

    switch(((AstCons*)obj)->type) {
        case ast_cons: {
            AstCons *p = obj;
            @<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons@>
            break;
        }
        case ast_symbol: {
            AstSymbol *symb = obj;
            code[(*pos)++] = (intptr_t)symb;
            break;
        }
        case ast_array: {
            AstArray *arr = obj;
            code[(*pos)++] = (intptr_t)ast_copy_obj(arr);
            break;
        }
        case ast_character: {
            AstCharacter *chr = obj;
            code[(*pos)++] = (intptr_t)ast_copy_obj(chr);
            break;
        }
        case ast_number: {
            AstNumber *num = obj;
            code[(*pos)++] = (intptr_t)ast_copy_obj(num);
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
if((AstSymbol*)car(p) == ast_progn) {
    if(cdr(p) == NULL) {
        fprintf(stderr, "\nprogn without args\n");
        exit(1);
    }

    AstCons *s;
    for(s = cdr(p); cdr(s) != NULL; s = cdr(s)) {
        danmakufu_compile_to_bytecode_helper(car(s), code, pos);
        // code[(*pos)++] = bc_drop;
    }

    danmakufu_compile_to_bytecode_helper(car(s), code, pos);
}
@}
можно запоминать глубину стека, но пока(для простоты) сделано из
  предположения, что функция возвращает всегда один параметр.
Выкидываем один элемент со стека после вызова, кроме последнего.
FIXME: на самом деле, многие вообще ничего не возвращают(пока),
  поэтому в vm надо временно отключить bc_drop для тестирования.
  Добавлено позже: похоже можно обойтись без этого drop вообще.
  Проблема возникает только при создании "висячих" выражений,
  результат которых ничему не присваивается.

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_defvar) {
    if(cdr(p) == NULL || cddr(p) == NULL) {
        fprintf(stderr, "\ndefvar without args\n");
        exit(1);
    }

    if(cadr(p)->type != ast_symbol) {
        fprintf(stderr, "\ndefvar: not symbol\n");
        exit(1);
    }

    if(car(cddr(p)) != NULL) {
        danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);
        code[(*pos)++] = bc_lit;
        code[(*pos)++] = (intptr_t)cadr(p);
        code[(*pos)++] = bc_setq;
    }
}
@}
TODO: ещё нет проверки на то, что символ уже определён

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_defscriptmain) {
    if(cdr(p) == NULL || cddr(p) == NULL) {
        fprintf(stderr, "\ndefscriptmain without args\n");
        exit(1);
    }

    // cadr(p) contains type of scriptmain
    code[(*pos)++] = bc_lit;
    code[(*pos)++] = (intptr_t)cadr(p);
    code[(*pos)++] = bc_lit;
    code[(*pos)++] = (intptr_t)ast_add_symbol_to_tbl("@script_type");
    code[(*pos)++] = bc_setq;

    // code[(*pos)++] = bc_scope_push;
    danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);
    // code[(*pos)++] = bc_scope_pop;
}
@}
FIXME: зачем я тут созадаю скоп? из-за этого @blabla не попадают в глобальный скоп.
  Возможно скоп и нужен, но именованный, а ещё лучше просто создавать новую машину

Вызов функции:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_funcall) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\nfuncall without args\n");
        exit(1);
    }

    AstCons *s;
    for(s = cddr(p); s != NULL; s = cdr(s))
        danmakufu_compile_to_bytecode_helper(car(s), code, pos);
    code[(*pos)++] = (intptr_t)cadr(p);
}
@}

Создание символа в scope и необязательное присваивание:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_implet) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\nimplet without args\n");
        exit(1);
    }

    if(cadr(p)->type != ast_symbol) {
        fprintf(stderr, "\nimplet: not symbol\n");
        exit(1);
    }

    code[(*pos)++] = bc_decl;
    code[(*pos)++] = (intptr_t)cadr(p);

    if(cddr(p) != NULL) {
        danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);

        code[(*pos)++] = bc_lit;
        code[(*pos)++] = (intptr_t)cadr(p);
        code[(*pos)++] = bc_setq;
    }
}
@}

Выйти из цикла:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_break) {

    code[(*pos)++] = bc_goto;

    code[(*pos)++] = last_break;
    last_break = *pos-1;
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
else if((AstSymbol*)car(p) == ast_return) {
    if(cadr(p) != NULL)
        danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

    code[(*pos)++] = bc_goto;

    code[(*pos)++] = last_return;
    last_return = *pos-1;
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
else if((AstSymbol*)car(p) == ast_defun) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\ndefun without args\n");
        exit(1);
    }

    @<danmakufu_bytecode.c defun - declare function@>
    if(cadr(cddr(p)) != NULL) {
        @<danmakufu_bytecode.c defun - generate parameters@>
        @<danmakufu_bytecode.c defun - generate body@>
    }
    @<danmakufu_bytecode.c defun - generate return@>
}
@}
Если тела нет, то параметры и тело генерировать не нужно

Команда на создание функции, имя функции, команда перехода,
  зарезервированная ячейка для перехода на неё:
@d danmakufu_bytecode.c defun - declare function @{
code[(*pos)++] = bc_defun;
code[(*pos)++] = (intptr_t)cadr(p);

int for_end_func = *pos;
code[(*pos)++] = 0;
@}
goto нужен, чтобы при объявлении функции не выполнять её тело.

@d danmakufu_bytecode.c defun - generate parameters @{
code[(*pos)++] = bc_scope_push;
@}


Из-за стека придётся перевернуть параметры местами. Пересчитаем количество
ячеек необходимое для параметров:
@d danmakufu_bytecode.c defun - generate parameters @{
int reserv = 0;

AstCons *s;
for(s = car(cddr(p)); s != NULL; s = cdr(s)) {
    if(car(s)->type == ast_symbol)
        reserv += 3;
    else if(car(s)->type == ast_cons && (AstSymbol*)caar(s) == ast_implet)
        reserv += 5;
    else {
        fprintf(stderr, "\ndefun incorrect args\n");
        exit(1);
    }
}
@}

Скомпилируем параметры в зависимости от их вида:
@d danmakufu_bytecode.c defun - generate parameters @{
*pos += reserv;

for(s = car(cddr(p)); s != NULL; s = cdr(s)) {
    if(car(s)->type == ast_symbol) {
        *pos -= 3;
        code[*pos] = bc_lit;
        code[*pos+1] = (intptr_t)car(s);
        code[*pos+2] = bc_setq;
    } else if(car(s)->type == ast_cons && (AstSymbol*)caar(s) == ast_implet) {
        *pos -= 5;
        code[*pos] = bc_decl;
        code[*pos+1] = (intptr_t)car(cdar(s));

        code[*pos+2] = bc_lit;
        code[*pos+3] = (intptr_t)car(cdar(s));
        code[*pos+4] = bc_setq;
    }
}

*pos += reserv;
@}

Скомпилируем тело функции:
@d danmakufu_bytecode.c defun - generate body @{
@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_return@>

danmakufu_compile_to_bytecode_helper(cadr(cddr(p)), code, pos);

@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_return@>
@}

Для коректной работы return сохраним старое значение last_return, и
присвоим ему 0:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_return @{
int old_last_return = last_return;
last_return = 0;
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

Закроем скоп,
@d danmakufu_bytecode.c defun - generate body @{
code[(*pos)++] = bc_scope_pop;
@}

Запишем команду выхода из функции и заполним ячейку после bc_goto:
@d danmakufu_bytecode.c defun - generate return @{
code[(*pos)++] = bc_ret;

code[for_end_func] = *pos;
@}
bc_ret нужно отделить от остального тела, так как тела может и не быть,
  а возвращаться из функции надо всегда.


Условный оператор if:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_if) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\nif without args\n");
        exit(1);
    }

    danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

    code[(*pos)++] = bc_if;

    int for_end = *pos;
    code[(*pos)++] = 0;

    if(car(cddr(p)) != NULL) {
        code[(*pos)++] = bc_scope_push;
        danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);
        code[(*pos)++] = bc_scope_pop;
    }

    code[for_end] = *pos;

    if(cadr(cddr(p)) != NULL) {
        code[(*pos)++] = bc_goto;
        int for_else = *pos;
        code[(*pos)++] = 0;

        code[for_end] = *pos;

        code[(*pos)++] = bc_scope_push;
        danmakufu_compile_to_bytecode_helper(cadr(cddr(p)), code, pos);
        code[(*pos)++] = bc_scope_pop;

        code[for_else] = *pos;
    }
}
@}

Оператор цикла loop:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_loop) {
    if(cadr(p) != NULL)
        danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

    int for_repeat = *pos;

    int for_loop;
    if(cadr(p) != NULL) {
        code[(*pos)++] = bc_repeat;

        for_loop = *pos;
        code[(*pos)++] = 0;
    }

    @<danmakufu_bytecode.c loop - body@>
    @<danmakufu_bytecode.c loop - repeater@>
    @<danmakufu_bytecode.c loop - end@>

    if(cadr(p) != NULL)
        code[for_loop] = *pos;
}
@}
Условие может отсутствовать, тогда ненужные части компилироваться не будут;
for_repeat - метка куда будет делаться goto из конца цикла
for_loop - метка для перехода когда число повторов станет 0


Тело цикла:
@d danmakufu_bytecode.c loop - body @{
@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_break@>

if(car(cddr(p)) != NULL) {
    code[(*pos)++] = bc_scope_push;

    danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);

    code[(*pos)++] = bc_scope_pop;
}
@}
создание и удаление скопа; сохранение метки для break; само тело цикла;
если тела нет, то ничего не компилируется

@d danmakufu_bytecode.c loop - repeater @{
code[(*pos)++] = bc_goto;
code[(*pos)++] = for_repeat;
@}
прыжок в начало цикла

@d danmakufu_bytecode.c loop - end @{
@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_break@>
if(car(cddr(p)) != NULL)
    code[(*pos)++] = bc_scope_pop;
@}
заполнение break'ов и дублирование закрытия скопа(так как первое мы перепрыгнем);


Оператор цикла while:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_while) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\nwhile without args\n");
        exit(1);
    }

    int for_begin = *pos;
    danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

    code[(*pos)++] = bc_if;

    int for_while = *pos;
    code[(*pos)++] = 0;

    @<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_break@>

    if(car(cddr(p)) != NULL) {
        code[(*pos)++] = bc_scope_push;
        danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);
        code[(*pos)++] = bc_scope_pop;
    }

    code[(*pos)++] = bc_goto;
    code[(*pos)++] = for_begin;

    @<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_break@>
    code[(*pos)++] = bc_scope_pop;

    code[for_while] = *pos;
}
@}
смотреть для loop

Оператор присваивания setq:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_setq) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\nsetq without args\n");
        exit(1);
    }

    danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);

    if(cadr(p)->type == ast_symbol) {
        code[(*pos)++] = bc_lit;
        code[(*pos)++] = (intptr_t)cadr(p);
        code[(*pos)++] = bc_setq;
    } else if((AstSymbol*)car(cadr(p)) == ast_funcall) {
        code[(*pos)++] = (intptr_t)ast_copy_obj(cadr(cddr(cadr(p))));
        code[(*pos)++] = bc_lit;
        code[(*pos)++] = (intptr_t)car(cddr(cadr(p)));
        code[(*pos)++] = (intptr_t)ast_add_symbol_to_tbl("index!");
    }
}
@}


Оператор создания массива:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_make_array) {
    int num_el = 0;

    if(cdr(p) != NULL && (AstSymbol*)car(cadr(p)) == ast_list) {
        AstCons *s;
        for(s = cdr(cadr(p)); s != NULL; s = cdr(s)) {
            danmakufu_compile_to_bytecode_helper(car(s), code, pos);
            num_el++;
        }
    } else if(cdr(p) != NULL) {
        fprintf(stderr, "\nmake-array incorrect args\n");
        exit(1);
    }

    code[(*pos)++] = bc_make_array;
    code[(*pos)++] = num_el;
}
@}


Объявление задачи:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_task) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\ntask without args\n");
        exit(1);
    }

    @<danmakufu_bytecode.c task - declare function@>
    if(cadr(cddr(p)) != NULL) {
        @<danmakufu_bytecode.c task - scope@>
    }
    @<danmakufu_bytecode.c task - generate return@>
}
@}

@d danmakufu_bytecode.c task - declare function @{
code[(*pos)++] = bc_defun;
code[(*pos)++] = (intptr_t)cadr(p);

int for_goto = *pos;
code[(*pos)++] = 0;
@}

@d danmakufu_bytecode.c task - scope @{
code[(*pos)++] = bc_scope_push;
@<danmakufu_bytecode.c task - generate parameters@>
@<danmakufu_bytecode.c task - generate fork@>
code[(*pos)++] = bc_scope_pop;
@}

@d danmakufu_bytecode.c task - generate parameters @{
int reserv = 0;

AstCons *s;
for(s = car(cddr(p)); s != NULL; s = cdr(s)) {
    if(car(s)->type == ast_symbol)
        reserv += 3;
    else if(car(s)->type == ast_cons && (AstSymbol*)caar(s) == ast_implet)
        reserv += 5;
    else {
        fprintf(stderr, "\ntask incorrect args\n");
        exit(1);
    }
}
@}

@d danmakufu_bytecode.c task - generate parameters @{
*pos += reserv;

for(s = car(cddr(p)); s != NULL; s = cdr(s)) {
    if(car(s)->type == ast_symbol) {
        *pos -= 3;
        code[*pos] = bc_lit;
        code[*pos+1] = (intptr_t)car(s);
        code[*pos+2] = bc_setq;
    } else if(car(s)->type == ast_cons && (AstSymbol*)caar(s) == ast_implet) {
        *pos -= 5;
        code[*pos] = bc_decl;
        code[*pos+1] = (intptr_t)car(cdar(s));

        code[*pos+2] = bc_lit;
        code[*pos+3] = (intptr_t)car(cdar(s));
        code[*pos+4] = bc_setq;
    }
}

*pos += reserv;
@}

bc_fork:
@d danmakufu_bytecode.c task - generate fork @{
code[(*pos)++] = bc_fork;

int for_fork = *pos;
code[(*pos)++] = 0;

@<danmakufu_bytecode.c task - generate body@>

code[for_fork] = *pos - for_fork;
@}
первый процесс переходит в конец функции(там где закрытие скопа и прочее)

@d danmakufu_bytecode.c task - generate body @{
@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_return@>

danmakufu_compile_to_bytecode_helper(cadr(cddr(p)), code, pos);

@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_return@>
@}

@d danmakufu_bytecode.c task - generate return @{
code[(*pos)++] = bc_ret;

code[for_goto] = *pos;
@}


Передача управления следующей задаче:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_yield) {
    code[(*pos)++] = bc_yield;
}
@}

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_block) {
    code[(*pos)++] = bc_scope_push;
    if(cadr(p) != NULL)
        danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);
    code[(*pos)++] = bc_scope_pop;
}
@}

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_alternative) {
    if(cdr(p) == NULL || cadr(p) == NULL) {
        fprintf(stderr, "\nalternative without args\n");
        exit(1);
    }

    @<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative@>
}
@}

Скомпилируем код условия(которое внутри alternative); подготовим переменные
  для break:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative @{
danmakufu_compile_to_bytecode_helper(cadr(p), code, pos);

@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_break@>
@}

Переменная для создания цепочки из goto передающих управление за блок alternative:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative @{
int last_end = 0;
@}

Обходим все case:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative @{
AstCons *s;
for(s = cdar(cddr(p)); s != NULL; s = cdr(s)) {
    @<danmakufu_bytecode.c alternative cases@>
}
@}

Переменная для создания цепочки из goto для перехода в начало case:
@d danmakufu_bytecode.c alternative cases @{
int last_goto_to_begin_case = 0;
@}
используется для перехода из блока условий внутрь case при удачном матчинге.

Перебрать все условия текущего case кроме последнего(или первого, если условие одно):
@d danmakufu_bytecode.c alternative cases @{
AstCons *z;
for(z = cdar(cdar(s)); cdr(z) != NULL; z = cdr(z)) {
    code[(*pos)++] = bc_dup;

    danmakufu_compile_to_bytecode_helper(car(z), code, pos);
    code[(*pos)++] = (intptr_t)ast_add_symbol_to_tbl("equalp");
    code[(*pos)++] = bc_if;

    code[*pos] = *pos + 3;
    (*pos)++;

    code[(*pos)++] = bc_goto;
    code[(*pos)++] = last_goto_to_begin_case;
    last_goto_to_begin_case = *pos - 1;
}
@}
дублируем вычисление из alternative, вычисляем условие в case, проверяем на равенство:
  если не равно, то переходим на следующий case(+3)
  если равно, то на начало тела case(оно находится благодаря last_goto_to_begin_case и
    цепочки goto ссылающихся на предыдущее goto)

Последнее условие из текущего case:
@d danmakufu_bytecode.c alternative cases @{
code[(*pos)++] = bc_dup;

danmakufu_compile_to_bytecode_helper(car(z), code, pos);
code[(*pos)++] = (intptr_t)ast_add_symbol_to_tbl("equalp");
code[(*pos)++] = bc_if;

int for_end_case = *pos;
code[(*pos)++] = 0;
@}
примерно тоже, что и у других условий(описаны выше), но при неудачном сравнении
  переходит в ячейку code[for_end_case], а при удачном оказывается в теле case(без
  всяких goto), так как тело идёт за последним условием.

Заполним цепочку goto в условиях текущего case:
@d danmakufu_bytecode.c alternative cases @{
while(last_goto_to_begin_case != 0) {
    int i = code[last_goto_to_begin_case];
    code[last_goto_to_begin_case] = *pos;
    last_goto_to_begin_case = i;
}
@}
теперь в случае успешного матчинга условие будет передавать управление в начало тела case.

Тело case вместе с объявлением скопа:
@d danmakufu_bytecode.c alternative cases @{
if(cadr(cdar(s)) != NULL) {
    code[(*pos)++] = bc_scope_push;
    danmakufu_compile_to_bytecode_helper(cadr(cdar(s)), code, pos);
    code[(*pos)++] = bc_scope_pop;
}
@}

Когда тело выполнится, то перейти за блок alternative:
@d danmakufu_bytecode.c alternative cases @{
code[(*pos)++] = bc_goto;
code[(*pos)++] = last_end;
last_end = *pos - 1;
@}
для этого формируем цепочку из goto и переменной last_end

Заполняем ячейку goto последнего условия case для перехода к следующему case'у:
@d danmakufu_bytecode.c alternative cases @{
code[for_end_case] = *pos;
@}


Блок other:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative @{
if(cadr(cddr(p)) != NULL) {
    code[(*pos)++] = bc_scope_push;
    danmakufu_compile_to_bytecode_helper(cadr(cddr(p)), code, pos);
    code[(*pos)++] = bc_scope_pop;
}

code[(*pos)++] = bc_goto;
code[(*pos)++] = last_end;
last_end = *pos - 1;
@}
если он присутствует, то он расположен как раз по-значению в code[for_end_case],
  те последний case передаст управление на other, если последний из его тестов
  будет отрицательным.
надо, чтобы перепрыгивало через блок для break в последнем case(если есть
  other, то это он последний case)

@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative @{
@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_break@>
code[(*pos)++] = bc_scope_pop;
@}
этот блок закроет скоп в случае выхода по break

Заполняем цепочку goto для выхода из блока alternative:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative @{
while(last_end != 0) {
    int i = code[last_end];
    code[last_end] = *pos;
    last_end = i;
}
@}

Выкидываем элемент полученный bc_dup:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper alternative @{
code[(*pos)++] = bc_drop;
@}
если case вообще нет, то надо выкинуть условие alternative

Различные @BlaBla {}
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_dog_name) {
    code[(*pos)++] = bc_defun;
    code[(*pos)++] = (intptr_t)cadr(p);

    int for_end_dog = *pos;
    code[(*pos)++] = 0;

    if(car(cddr(p)) != NULL) {
        code[(*pos)++] = bc_scope_push;
        danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);
        code[(*pos)++] = bc_scope_pop;
    }

    code[(*pos)++] = bc_ret;

    code[for_end_dog] = *pos;
}
@}
оформляются как функции в текущем скопе. Те вначале мы выполняем байт код, получаем функции
  @BlaBla и некоторую инициализацию; далее ищем функции @BlaBla в скопе и выполняем когда нужно.


Циклы ascent и descent:
@d danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper cons @{
else if((AstSymbol*)car(p) == ast_ascent || (AstSymbol*)car(p) == ast_descent) {
    bytecode_xcent(p, code, pos);
}
@}


@d danmakufu_bytecode.c prototypes @{
static void bytecode_xcent(AstCons *p, intptr_t *code, int *pos);
@}
ascent или descent догадается по содержимому p

@d danmakufu_bytecode.c functions @{
static void bytecode_xcent(AstCons *p, intptr_t *code, int *pos) {
    @<danmakufu_bytecode.c bytecode_xcent@>
}
@}

Интервал, вначале "до", потом "от":
@d danmakufu_bytecode.c bytecode_xcent @{
danmakufu_compile_to_bytecode_helper(cadr(cddr(p)), code, pos);
danmakufu_compile_to_bytecode_helper(car(cddr(p)), code, pos);
@}

Сохранить в переменной:
@d danmakufu_bytecode.c bytecode_xcent @{
if((AstSymbol*)car(cadr(p)) == ast_implet) {
    code[(*pos)++] = bc_scope_push;

    code[(*pos)++] = bc_decl;
    code[(*pos)++] = (intptr_t)cadr(cadr(p));
}

int for_begin = *pos;
code[(*pos)++] = bc_dup;

code[(*pos)++] = bc_lit;

if(cadr(p)->type == ast_symbol)
    code[(*pos)++] = (intptr_t)cadr(p);
else if((AstSymbol*)car(cadr(p)) == ast_implet)
    code[(*pos)++] = (intptr_t)cadr(cadr(p));
else {
    fprintf(stderr, "\nascent incorrect args\n");
    exit(1);
}

code[(*pos)++] = bc_setq;
@}
если был "let", то создаётся скоп;
for_begin - метка для перехода в начало при следующей итерации;

Проверить условие:
@d danmakufu_bytecode.c bytecode_xcent @{
code[(*pos)++] = bc_2dup;

if((AstSymbol*)car(p) == ast_ascent)
    code[(*pos)++] = (intptr_t)ast_add_symbol_to_tbl(">");
else
    code[(*pos)++] = (intptr_t)ast_add_symbol_to_tbl("<");
code[(*pos)++] = bc_if;

int for_end_xcent = *pos;
code[(*pos)++] = 0;
@}
дублируем "до" и "от", проверяем и переходим.
for_end_xcent - метка из цикла xcent

Тело цикла:
@d danmakufu_bytecode.c bytecode_xcent @{
@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper save last_break@>
if(car(cddr(cddr(p))) != NULL) {
    code[(*pos)++] = bc_scope_push;
    danmakufu_compile_to_bytecode_helper(car(cddr(cddr(p))), code, pos);
    code[(*pos)++] = bc_scope_pop;
}
@}

Конец итерации:
@d danmakufu_bytecode.c bytecode_xcent @{
if((AstSymbol*)car(p) == ast_ascent)
    code[(*pos)++] = bc_inc;
else
    code[(*pos)++] = bc_dec;

code[(*pos)++] = bc_goto;
code[(*pos)++] = for_begin;
@}
Меняем значение счётчика и повторяем цикл.

Обработка выхода по break:
@d danmakufu_bytecode.c bytecode_xcent @{
@<danmakufu_bytecode.c danmakufu_compile_to_bytecode_helper restore last_break@>
if(car(cddr(cddr(p))) != NULL && (AstSymbol*)car(cadr(p)) != ast_implet)
    code[(*pos)++] = bc_scope_pop;
@}
условие "(AstSymbol*)car(cadr(p)) == ast_implet" нужно, чтобы bc_scope_pop не шёл два
  раза подряд(второй bc_scope_pop описан ниже), если что-то не так, то лучше это условие
  убрать

Чистим:
@d danmakufu_bytecode.c bytecode_xcent @{
code[for_end_xcent] = *pos;

if((AstSymbol*)car(cadr(p)) == ast_implet)
    code[(*pos)++] = bc_scope_pop;

code[(*pos)++] = bc_2drop;
@}
заполняем метку для выхода из цикла; закрываем внешний скоп, если был "let";
  выкидываем "от" и "до".

Печать байткода:
@d danmakufu_bytecode.c functions @{
void danmakufu_print_bytecode(intptr_t *code, int size) {
    int i;

    for(i=0; i < size; i++) {
        printf("%d) ", i);
        switch(code[i]) {
            case bc_lit:
                printf("bc_lit\n");
                i++;
                printf("%s\n", ((AstSymbol*)code[i])->name);
                break;
            case bc_setq:
                printf("bc_setq\n");
                break;
            case bc_drop:
                printf("bc_drop\n");
                break;
            case bc_2drop:
                printf("bc_2drop\n");
                break;
            case bc_dup:
                printf("bc_dup\n");
                break;
            case bc_2dup:
                printf("bc_2dup\n");
                break;
            case bc_decl:
                printf("bc_decl\n");
                i++;
                printf("%s\n", ((AstSymbol*)code[i])->name);
                break;
            case bc_scope_push:
                printf("bc_scope_push\n");
                break;
            case bc_scope_pop:
                printf("bc_scope_pop\n");
                break;
            case bc_defun:
                printf("bc_defun\n");
                i++;
                printf("%s\n", ((AstSymbol*)code[i])->name);
                i++;
                printf("%d\n", (int)code[i]);
                break;
            case bc_ret:
                printf("bc_ret\n");
                break;
            case bc_goto:
                printf("bc_goto\n");
                i++;
                printf("%d\n", (int)code[i]);
                break;
            case bc_if:
                printf("bc_if\n");
                i++;
                printf("%d\n", (int)code[i]);
                break;
            case bc_repeat:
                printf("bc_repeat\n");
                i++;
                printf("%d\n", (int)code[i]);
                break;
            case bc_make_array:
                printf("bc_make_array\n");
                i++;
                printf("%d\n", (int)code[i]);
                break;
            case bc_fork:
                printf("bc_fork\n");
                i++;
                printf("%d\n", (int)code[i]);
                break;
            case bc_yield:
                printf("bc_yield\n");
                break;
            case bc_inc:
                printf("bc_inc\n");
                break;
            case bc_dec:
                printf("bc_dec\n");
                break;
            default:
                if(((AstSymbol*)code[i])->type == ast_symbol)
                    printf("%s\n", ((AstSymbol*)code[i])->name);
                else if(((AstSymbol*)code[i])->type == ast_number)
                    printf("%f\n", ((AstNumber*)code[i])->number);
                else if(((AstSymbol*)code[i])->type == ast_array ||
                        ((AstSymbol*)code[i])->type == ast_character)
                    ast_print((void*)code[i]), printf("\n");
                else
                    printf("%d\n", (int)code[i]);
        }
    }
}
@}

@d danmakufu_bytecode.h prototypes @{
void danmakufu_print_bytecode(intptr_t *code, int size);
@}
