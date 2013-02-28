/*
 *  Copyright 2006-2012 Adrian Thurston <thurston@complang.org>
 */

/*  This file is part of Colm.
 *
 *  Colm is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 * 
 *  Colm is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 * 
 *  You should have received a copy of the GNU General Public License
 *  along with Colm; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
 */

#include "parsedata.h"
#include "fsmcodegen.h"
#include "redfsm.h"
#include "bstmap.h"
#include "debug.h"
#include <sstream>
#include <string>

using std::ostream;
using std::ostringstream;
using std::string;
using std::cerr;
using std::endl;

void Compiler::openNameSpace( ostream &out, Namespace *nspace )
{
	if ( nspace == defaultNamespace || nspace == rootNamespace )
		return;
	
	openNameSpace( out, nspace->parentNamespace );
	out << "namespace " << nspace->name << " { ";
}

void Compiler::closeNameSpace( ostream &out, Namespace *nspace )
{
	if ( nspace == defaultNamespace || nspace == rootNamespace )
		return;
	
	openNameSpace( out, nspace->parentNamespace );
	out << " }";
}

void Compiler::generateExports()
{
	ostream &out = *outStream;

	out << 
		"#ifndef _EXPORTS_H\n"
		"#define _EXPORTS_H\n"
		"\n"
		"#include <colm/colm.h>\n"
		"#include <string>\n"
		"\n";
	
	out << 
		"inline void appendString( ColmPrintArgs *args, const char *data, int length )\n"
		"{\n"
		"	std::string *str = (std::string*)args->arg;\n"
		"	*str += std::string( data, length );\n"
		"}\n"
		"\n";

	out << 
		"inline std::string printTreeStr( ColmProgram *prg, ColmTree *tree, bool trim )\n"
		"{\n"
		"	std::string str;\n"
		"	ColmPrintArgs printArgs = { &str, 1, 0, trim, &appendString, \n"
		"			&printNull, &printTermTree, &printNull };\n"
		"	printTreeArgs( prg, vm_root(prg), &printArgs, tree );\n"
		"	return str;\n"
		"}\n"
		"\n";

	/* Declare. */
	for ( LelList::Iter lel = langEls; lel.lte(); lel++ ) {
		if ( lel->isEOF ) {
			out << "// isEOF\n";
			continue;
		}
		if ( lel->tokenDef != 0 && lel->tokenDef->tokenRegion != 0 &&
				lel->tokenDef->tokenRegion->isTokenOnly )
		{
			out << "// isTokenOnly\n";
			continue;
		}
		if ( lel->tokenDef != 0 && lel->tokenDef->tokenRegion != 0 &&
				lel->tokenDef->tokenRegion->isIgnoreOnly )
		{
			out << "// isIgnoreOnly\n";
			continue;
		}
		if ( lel->tokenDef != 0 && lel->tokenDef->tokenRegion != 0 &&
				lel->tokenDef->tokenRegion->isCiOnly )
		{
			out << "// isCiOnly\n";
			continue;
		}
		if ( lel->isCI != 0 ) {
			out << "// isCI != 0\n";
			continue;
		}	
		openNameSpace( out, lel->nspace );
		out << "struct " << lel->fullName << ";";
		closeNameSpace( out, lel->nspace );
		out << "\n";
	}

	/* Class definitions. */
	for ( LelList::Iter lel = langEls; lel.lte(); lel++ ) {
		if ( lel->isEOF ) {
			out << "// isTokenOnly\n";
			continue;
		}
		if ( lel->tokenDef != 0 && lel->tokenDef->tokenRegion != 0 &&
				lel->tokenDef->tokenRegion->isTokenOnly )
		{
			out << "// isTokenOnly\n";
			continue;
		}
		if ( lel->tokenDef != 0 && lel->tokenDef->tokenRegion != 0 &&
				lel->tokenDef->tokenRegion->isIgnoreOnly )
		{
			out << "// isIgnoreOnly\n";
			continue;
		}
		if ( lel->tokenDef != 0 && lel->tokenDef->tokenRegion != 0 &&
				lel->tokenDef->tokenRegion->isCiOnly )
		{
			out << "// isCiOnly\n";
			continue;
		}
		if ( lel->isCI != 0 ) {
			out << "// isCI != 0\n";
			continue;
		}	

		openNameSpace( out, lel->nspace );
		out << "struct " << lel->fullName << "\n";
		out << "{\n";
		out << "	std::string text() { return printTreeStr( __prg, __tree, true ); }\n";
		out << "	std::string text_notrim() { return printTreeStr( __prg, __tree, false ); }\n";
		out << "	operator ColmTree *() { return __tree; }\n";
		out << "	ColmProgram *__prg;\n";
		out << "	ColmTree *__tree;\n";

		if ( mainReturnUT != 0 && mainReturnUT->langEl == lel ) {
			out << "	" << lel->fullName << "( ColmProgram *prg ) : __prg(prg), __tree(returnVal(prg)) {}\n";
		}
		out << "	" << lel->fullName << "( ColmProgram *prg, ColmTree *tree ) : __prg(prg), __tree(tree) {}\n";

		if ( lel->objectDef != 0 && lel->objectDef->objFieldList != 0 ) {
			ObjFieldList *objFieldList = lel->objectDef->objFieldList;
			for ( ObjFieldList::Iter ofi = *objFieldList; ofi.lte(); ofi++ ) {
				ObjectField *field = ofi->value;
				if ( field->useOffset && field->typeRef != 0  ) {
					UniqueType *ut = field->typeRef->lookupType( this );

					if ( ut != 0 && ut->typeId == TYPE_TREE  ) {
						out << "	" << ut->langEl->refName << " " << field->name << "();\n";
					}
				}

				if ( field->isRhsGet ) {
					UniqueType *ut = field->typeRef->lookupType( this );

					if ( ut != 0 && ut->typeId == TYPE_TREE  ) {
						out << "	" << ut->langEl->refName << " " << field->name << "();\n";
					}
				}
			}
		}

		if ( lel->isRepeat ) {
			out << "	" << "int end() { return repeatEnd( __tree ); }\n";
			out << "	" << lel->refName << " next();\n";
			out << "	" << lel->repeatOf->refName << " value();\n";
		}

		if ( lel->isList ) {
			out << "	" << "int last() { return listLast( __tree ); }\n";
			out << "	" << lel->refName << " next();\n";
			out << "	" << lel->repeatOf->refName << " value();\n";
		}
		out << "};";
		closeNameSpace( out, lel->nspace );
		out << "\n";
	}

	for ( ObjFieldList::Iter of = *globalObjectDef->objFieldList; of.lte(); of++ ) {
		ObjectField *field = of->value;
		if ( field->isExport ) {
			UniqueType *ut = field->typeRef->lookupType(this);
			if ( ut != 0 && ut->typeId == TYPE_TREE  ) {
				out << ut->langEl->refName << " " << field->name << "( ColmProgram *prg );\n";
			}
		}
	}
	
	out << "#endif\n";
}

void Compiler::generateExportsImpl()
{
	ostream &out = *outStream;

	if ( gblExportTo != 0 )  {
		out << "#include \"" << gblExportTo << "\"\n";
	}

	/* Function implementations. */
	for ( LelList::Iter lel = langEls; lel.lte(); lel++ ) {
		if ( lel->objectDef != 0 && lel->objectDef->objFieldList != 0 ) {
			ObjFieldList *objFieldList = lel->objectDef->objFieldList;
			for ( ObjFieldList::Iter ofi = *objFieldList; ofi.lte(); ofi++ ) {
				ObjectField *field = ofi->value;
				if ( field->useOffset && field->typeRef != 0  ) {
					UniqueType *ut = field->typeRef->lookupType( this );

					if ( ut != 0 && ut->typeId == TYPE_TREE  ) {
						out << ut->langEl->refName << " " << lel->declName << "::" << field->name << 
							"() { return " << ut->langEl->refName << 
							"( __prg, getAttr( __tree, " << field->offset << ") ); }\n";
					}
				}

				if ( field->isRhsGet ) {
					UniqueType *ut = field->typeRef->lookupType( this );

					if ( ut != 0 && ut->typeId == TYPE_TREE  ) {
						out << ut->langEl->refName << " " << lel->declName << "::" << field->name << 
							"() { static int a[] = {"; 

						/* Need to place the array computing the val. */
						out << field->rhsVal.length();
						for ( Vector<RhsVal>::Iter rg = field->rhsVal; rg.lte(); rg++ ) {
							out << ", " << rg->prodEl->production->prodNum;
							out << ", " << rg->prodEl->pos;
						}

						out << "}; return " << ut->langEl->refName << 
							"( __prg, getRhsVal( __prg, __tree, a ) ); }\n";
					}
				}
			}
		}

		if ( lel->isRepeat ) {
			out << lel->refName << " " << lel->declName << "::" << " next"
				"() { return " << lel->refName << 
				"( __prg, getRepeatNext( __tree ) ); }\n";

			out << lel->repeatOf->refName << " " << lel->declName << "::" << " value"
				"() { return " << lel->repeatOf->refName << 
				"( __prg, getRepeatVal( __tree ) ); }\n";

		}

		if ( lel->isList ) {
			out << lel->refName << " " << lel->declName << "::" << " next"
				"() { return " << lel->refName << 
				"( __prg, getRepeatNext( __tree ) ); }\n";

			out << lel->repeatOf->refName << " " << lel->declName << "::" << " value"
				"() { return " << lel->repeatOf->refName << 
				"( __prg, getRepeatVal( __tree ) ); }\n";
		}
	}

	out << "\n";

	for ( ObjFieldList::Iter of = *globalObjectDef->objFieldList; of.lte(); of++ ) {
		ObjectField *field = of->value;
		if ( field->isExport ) {
			UniqueType *ut = field->typeRef->lookupType(this);
			if ( ut != 0 && ut->typeId == TYPE_TREE  ) {
				out << 
					ut->langEl->refName << " " << field->name << "( ColmProgram *prg )\n"
					"{ return " << ut->langEl->refName << "( prg, getGlobal( prg, " << 
					field->offset << ") ); }\n";
			}
		}
	}
}


