#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>

#define LIST_APPEND( pphead, element ) \
	{ \
		element->next = *pphead; \
		*pphead = element; \
	}

#define STACK_PUSH( pphead, element ) \
	{ \
		element->parent = *pphead; \
		*pphead = element; \
	}

#define STACK_POP( pphead ) \
	{ \
		*pphead = (*pphead)->parent; \
	}

#define REVERSE_LIST( S, pphead ) \
	if ( *pphead != 0 ) { \
		S *front = (*pphead)->next; \
		(*pphead)->next = 0; \
		while ( front != NULL ) { \
			S *next = front->next; \
			front->next = *pphead; \
			*pphead = front; \
			front = next; \
		} \
	}

struct value
{
	int v;

	struct value *next;
};

struct quantifier
{
	
};

enum element_type
{
	element_value_type = 1,
	element_regex_type,
	element_look_around_type,
	element_char_class_type,
	element_back_ref_type
};

struct element
{
	enum element_type type;
	struct regex *regex;
	struct look_around *look_around;
	struct quantifier *quantifier;
	struct value *value_list;

	struct element *next;
};

struct term
{
	struct element *element_list;

	struct term *next;
	struct term *parent;
};

enum regex_type
{
	regex_non_capture = 1,
	regex_capture,
	regex_look_around
};

struct regex
{
	struct term *term_list;

	enum regex_type type;
	int capture;
	int node_id;
	int options;

	struct regex *next;
	struct regex *parent;
};

struct pattern
{
	struct regex *regex;
	int node_id;
	int is_look_around;

	struct look_around *look_arounds;
	struct pattern *parent;
};

enum look_around_type {
	lat_pos_ahead = 1,
	lat_neg_ahead,
	lat_pos_behind,
	lat_neg_behind,
};

struct look_around
{
	enum look_around_type type;
	struct pattern *pattern;
	int node_id;

	struct look_around *next;
};

struct value *new_value( int v )
{
	struct value *value = malloc( sizeof( struct value ) );
	memset( value, 0, sizeof(struct value) );
	value->v = v;
	return value;
}

struct term *new_term( void )
{
	struct term *term = malloc( sizeof( struct term ) );
	memset( term, 0, sizeof(struct term) );
	return term;
}

struct element *new_element( enum element_type type, struct regex *regex, struct look_around *look_around )
{
	struct element *element = malloc( sizeof( struct element ) );
	memset( element, 0, sizeof(struct element) );
	element->type = type;
	element->regex = regex;
	element->look_around = look_around;
	return element;
}

struct regex *new_regex( enum regex_type type, int options )
{
	struct regex *regex = malloc( sizeof( struct regex ) );
	memset( regex, 0, sizeof(struct regex) );
	regex->type = type;
	regex->options = options;
	return regex;
}

struct look_around *new_look_around( enum look_around_type lat, struct pattern *pattern )
{
	struct look_around *look_around = malloc( sizeof( struct look_around ) );
	memset( look_around, 0, sizeof(struct look_around) );
	look_around->type = lat;
	look_around->pattern = pattern;
	return look_around;
}

struct pattern *new_pattern( struct regex *regex, int is_look_around )
{
	struct pattern *pattern = malloc( sizeof( struct pattern ) );
	pattern->regex = regex;
	pattern->is_look_around = is_look_around;
	return pattern;
}

void append_element_value( struct term *term, int value )
{
	struct element *el = term->element_list;
	if ( el == NULL ||
			el->type != element_value_type ||
			el->quantifier != 0 )
	{
		el = new_element( element_value_type, NULL, NULL );
		LIST_APPEND( &term->element_list, el );
	}
	
	struct value *v = new_value( value );
	LIST_APPEND( &el->value_list, v );
}

void reverse_value_list( struct value **pphead )
{
	REVERSE_LIST( struct value, pphead );
}

void reverse_element_list( struct element **pphead )
{
	REVERSE_LIST( struct element, pphead );
}

void reverse_term_list( struct term **pphead )
{
	REVERSE_LIST( struct term, pphead );
}


/* Provides initial ragel call state stack. */
int *init_ragel_stack( int *size )
{
	*size = 24;
	return malloc( *size * sizeof(int) );
}

/* Grows the ragel call state stack. Use in pre-push. */
int *grow_ragel_stack( int *size, int *stack )
{
	int new_size = *size * 2;
	int *new_stack = malloc( new_size * sizeof(int) ) ;
	memcpy( new_stack, stack, *size * sizeof(int) );
	free( stack );

	*size = new_size;
	return new_stack;
}

%%{
	machine PCRE;

	action enter_term {
		struct term *term = new_term();
		STACK_PUSH( &s_term, term );
		LIST_APPEND( &s_regex->term_list, term );
	}

	action leave_term {
		reverse_element_list( &s_term->element_list );
		struct element *el = s_term->element_list;
		while ( el != 0 ) {
			reverse_value_list( &el->value_list );
			el = el->next;
		}
		STACK_POP( &s_term );
	}

	action enter_regex {
		struct regex *regex = new_regex( regex_non_capture, s_regex->options );
		struct element *element = new_element( element_regex_type, regex, NULL );
		LIST_APPEND( &s_term->element_list, element );
		STACK_PUSH( &s_regex, regex );
	}

	action enter_lookaround {
		struct regex *regex = new_regex( regex_look_around, s_regex->options );
		struct pattern *pattern = new_pattern( regex, 1 );
		struct look_around *la = new_look_around( lat, pattern );
		pattern->node_id = la->node_id;

		LIST_APPEND( &s_pattern->look_arounds, la );

		struct element *element = new_element( element_look_around_type, NULL, la );
		LIST_APPEND( &s_term->element_list, element );

		STACK_PUSH( &s_regex, regex );
		STACK_PUSH( &s_pattern, pattern );
	}

	action leave_regex {
		if ( s_regex->type == regex_capture )
			closed_captures += 1;

		if ( s_regex->type == regex_look_around )
			STACK_POP( &s_pattern );

		reverse_term_list( &s_regex->term_list );
		STACK_POP( &s_regex );
	}

	action options_only { fret; }

	options = (
			'c' # case-sensitive matching
		|	'i' # case-insensitive matching
	)*;

	quant_forms = '_';

	atom =
		[a-z] @{ append_element_value( s_term, *p ); } |
		'(' @{ fcall paren_open; }
	;

	non_greedy = '_';

	quantifier = quant_forms non_greedy?;

	element = ( atom quantifier? );

	term = ( element** ) >enter_term;

	#
	# Expression
	#
	expr = term ( '|' @leave_term term )*;

	#
	# Regex
	#
	regex = expr;

	paren_open :=
		# Look at the first few charcters to see what the form is. What we
		# handle here:
		#  (re)    capturing parens
		#  (?:re)  non-capturing parens
		#  (?=re)  positive lookahead
		#  (?!re)  negative lookahead
		#  (?<=re) positive lookbehind 
		#  (?<!re) negative lookbehind
		(
			# Non-capture. 
			'?' options  ( ')' @options_only | ':' @enter_regex ) |

			# Lookaround
			(
				'?=' @{ lat = lat_pos_ahead; } @enter_lookaround |
				'?!' @{ lat = lat_neg_ahead; } @enter_lookaround |
				'?<=' @{ lat = lat_pos_behind; } @enter_lookaround |
				'?<!' @{ lat = lat_neg_behind; } @enter_lookaround
			) |
			# Catpuring.
			^'?' @enter_regex @{
				s_regex->type = regex_capture;
				s_regex->capture = next_capture++;
				fhold;
			}
		)
		regex ')' @leave_term @leave_regex @{ fret; };


	main := regex '\n' @leave_term @leave_regex @{ success = 1; };
}%%

%% write data;

int pcre_parse( struct pattern **result_pattern, char *line, int len )
{
	int *stack;
	int stack_size;
	int cs, top;
	char *p, *pe;
	int success = 0;
	int result = 1;

	struct pattern *s_pattern = 0;
	struct regex *s_regex = 0;
	struct term *s_term = 0;

	/* Collect into this. */
	struct regex *root_regex = new_regex( regex_non_capture, 0 );
	struct pattern *root_pattern = new_pattern( root_regex, 0 );
	STACK_PUSH( &s_pattern, root_pattern );
	STACK_PUSH( &s_regex, root_regex );

	int closed_captures = 0;
	int next_capture = 1;

	enum look_around_type lat;

	stack = init_ragel_stack( &stack_size );

	%% write init;

	p = line;
	pe = line + len;

	%% write exec;

	if ( !success ) {
		printf( "parse error at %ld\n", ( p - line + 1) );
		result = 0;
	}
	else if (
			s_pattern == NULL || s_pattern->parent != NULL ||
			s_regex != NULL || 
			s_term != NULL )
	{
		printf( "parse error: items not closed\n" );
		result = 0;
	}

	if ( result ) {
		*result_pattern = root_pattern;
	}
	else {
	
	}

	free( stack );

	return result;
}

extern void print_value( int indent, struct value *value );
extern void print_element( int indent, struct element *el );
extern void print_term( int indent, struct term *term );
extern void print_regex( int indent, struct regex *regex );

void print_indent( int indent )
{
	while ( indent-- > 0 )
		printf( "  " );
}

void print_value( int indent, struct value *value )
{
	printf( "v(%d)", value->v );
}

void print_element( int indent, struct element *el )
{
	print_indent( indent );
	printf( "el: " );
	if ( el->type == element_value_type ) {
		struct value *value = el->value_list;
		while ( value != NULL ) {
			print_value( indent + 1, value );
			if ( value->next != 0 )
				printf( " . " );
			value = value->next;
		}
		printf("\n");
	}
	else if ( el->type == element_regex_type ) {
		printf("\n");
		if ( el->regex != 0 )
			print_regex( indent + 1, el->regex );
	}
	else if ( el->type == element_look_around_type )
		printf( "lookaround\n" );
	else if ( el->type == element_char_class_type )
		printf( "cc\n" );
	else if ( el->type == element_back_ref_type )
		printf( "backref\n" );
}

void print_term( int indent, struct term *term )
{
	print_indent( indent );
	printf( "term:\n" );
	struct element *el = term->element_list;
	while ( el != NULL ) {
		print_element( indent + 1, el );
		el = el->next;
	}
}

void print_regex( int indent, struct regex *regex )
{
	print_indent( indent );
	printf( "reg:\n" );

	struct term *term = regex->term_list;
	while ( term != NULL ) {
		print_term( indent + 1, term );
		term = term->next;
	}
}

void print_pattern( int indent, struct pattern *pat )
{
	printf( "pat:\n" );
	print_regex( indent + 1, pat->regex );
}

char linebuf[2048];

int main( int argc, char **argv )
{
	if ( argc < 2 ) {
		fprintf( stderr, "usage: ./pcre <regex>\n" );
		return -1;
	}

	FILE *input = fopen( argv[1], "r" );
	if ( input == NULL ) {
		fprintf( stderr, "failed to open %s: %s", argv[0], strerror(errno) );
		return -1;
	}

	char *line = NULL;
	size_t n = 0;
	ssize_t read;

	while ( (read = getline( &line, &n, input )) != -1 ) {
		struct pattern *pat;
		int parsed = pcre_parse( &pat, line, (int)read );
		if ( parsed ) {
			print_pattern( 0, pat );
		}
	}

	fclose( input );
	free( line );
	return 0;
}
