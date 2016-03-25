////////////////////////////////////////////////////////////////////////////////
//
//  © 2010 BlooDHounD
//
////////////////////////////////////////////////////////////////////////////////

package by.blooddy.crypto.image {

	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	
	import by.blooddy.crypto.image.palette.IPalette;
	import by.blooddy.crypto.image.palette.MedianCutPalette;

	/**
	 * Encodes image data using 8 bits of color information per pixel.
	 *
	 * @author					BlooDHounD
	 * @version					1.0
	 * @playerversion			Flash 10.1
	 * @langversion				3.0
	 */
	public final class PNG8Encoder extends PNGEncoder {

		//--------------------------------------------------------------------------
		//
		//  Class methods
		//
		//--------------------------------------------------------------------------

		/**
		 * Creates a PNG-encoded byte sequence from the specified <code>BitmapData</code>
		 *
		 * @param	image			The <code>BitmapData</code> of the image you wish to encode.
		 *
		 * @param	filter			The encoding algorithm you wish to apply while encoding.
		 * 							Use the constants provided in
		 * 							<code>by.blooddy.crypto.image.PNGFilter</code> class.
		 *
		 * @param	palette			The color patette to use.
		 * 							If <code>null</code> given, the
		 * 							<code>by.blooddy.crypto.image.palette.MedianCutPalette</code>
		 * 							will be used.
		 *
		 * @return					The sequence of bytes containing the encoded image.
		 *
		 * @throws	TypeError		
		 * @throws	ArgumentError	No such filter.
		 *
		 * @see 					by.blooddy.crypto.image.palette.IPalette
		 * @see 					by.blooddy.crypto.image.palette.MedianCutPalette
		 * @see 					by.blooddy.crypto.image.PNGFilter
		 */
		public static function encode(image:BitmapData, filter:uint=0, palette:IPalette=null):ByteArray {
			
			if ( image == null ) Error.throwError( TypeError, 2007, 'image' );
			if ( filter < 0 || filter > 4 ) Error.throwError( ArgumentError, 2008, 'filter' );
			
			return $encode( image, filter, palette || new MedianCutPalette( image ) );

		}

		/**
		 * @private
		 */
		private static function $encode(image:BitmapData, filter:uint, palette:IPalette):ByteArray {
			
			var transparent:Boolean = isTransparent( image );
			
			// create output byte array
			var result:ByteArray = new ByteArray();
			
			// PNG signature
			writeSignature( result );
			
			// IHDR
			writeIHDR( result, image.width, image.height, 0x08, 0x03 );
			
			// PLTE, tRNS
			var plte:Vector.<ByteArray> = PNG8Encoder$.encodePalette( transparent, palette );
			writePLTE( result, plte[ 0 ] );
			if ( plte[ 1 ] ) {
				writeTRNS( result, plte[ 1 ] );
			}
			
			// IDAT
			writeIDAT( result, PNG8Encoder$.encode( image, filter, transparent, palette ) );
			
			// tEXt
			writeTEXT( result, 'Software', 'by.blooddy.crypto.image.PNG8Encoder' );
			
			// IEND
			writeIEND( result );
			
			return result;
			
		}
		
		private static function writePLTE(mem:ByteArray, plte:ByteArray):void {
			
			var chunk:ByteArray = _TMP;
			
			chunk.writeUnsignedInt( 0x504C5445 );
			chunk.writeBytes( plte );
			
			writeChunk( mem, chunk );
			
			chunk.length = 0;

		}
		
		private static function writeTRNS(mem:ByteArray, trns:ByteArray):void {
			
			var chunk:ByteArray = _TMP;
			
			chunk.writeUnsignedInt( 0x74524E53 );
			chunk.writeBytes( trns );
			
			writeChunk( mem, chunk );
			
			chunk.length = 0;

		}
		
		//--------------------------------------------------------------------------
		//
		//  Constructor
		//
		//--------------------------------------------------------------------------
		
		/**
		 * @private
		 * Constructor
		 */
		public function PNG8Encoder() {
			Error.throwError( ArgumentError, 2012, getQualifiedClassName( this ) );
		}
		
	}

}

import flash.display.BitmapData;
import flash.system.ApplicationDomain;
import flash.utils.ByteArray;

import avm2.intrinsics.memory.li8;
import avm2.intrinsics.memory.si8;

import by.blooddy.core.utils.ByteArrayUtils;
import by.blooddy.crypto.image.palette.IPalette;

/**
 * @private
 */
internal final class PNG8Encoder$ {
	
	//--------------------------------------------------------------------------
	//
	//  Encode
	//
	//--------------------------------------------------------------------------
	
	internal static function encodePalette(transparent:Boolean, palette:IPalette):Vector.<ByteArray> {
		
		var colors:Vector.<uint> = palette.getList();
		
		var tmp:ByteArray = _DOMAIN.domainMemory;
		
		var plte:ByteArray = new ByteArray();
		plte.length = Math.max( 1024, ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH );
		
		_DOMAIN.domainMemory = plte;

		var c:int = 0;
		
		var i:int = 0;
		var j:int = 256 * 3;
		var k:int = 0;
		var l:uint = colors.length;

		for ( ; k<l; ++k ) {
		
			c = colors[ k ];
			
			// transparent
			if ( transparent ) {
				si8( c >> 24, j++ );
			}
			
			// rgb
			si8( c >> 16, i++ );
			si8( c >>  8, i++ );
			si8( c      , i++ );
		
		}

		_DOMAIN.domainMemory = tmp;
		
		var trns:ByteArray;
		if ( transparent ) {
			trns = new ByteArray();
			trns.writeBytes( plte, 256 * 3, l );
			trns.position = 0;
		}
		
		plte.length = l * 3;
		var result:Vector.<ByteArray> = new Vector.<ByteArray>( 2, true );
		result[ 0 ] = plte;
		result[ 1 ] = trns;
		
		return result;//new <ByteArray>[ plte, trns ];
	}
	
	internal static function encode(image:BitmapData, filter:uint, transparent:Boolean, palette:IPalette):ByteArray {

		var tmp:ByteArray = _DOMAIN.domainMemory;
		
		var mem:ByteArray = new ByteArray();
		mem.length = Math.max(
			image.width * image.height + image.height + image.width * 4,
			ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH
		);

		_DOMAIN.domainMemory = mem;
		
		_ENCODERS[ int( transparent ) ][ filter ]( image, palette );
		
		_DOMAIN.domainMemory = tmp;

		return mem;
		
	}
	
	//--------------------------------------------------------------------------
	//  encode main methods
	//--------------------------------------------------------------------------
	
	private static const _DOMAIN:ApplicationDomain = ApplicationDomain.currentDomain;
	
	private static const _ENCODERS:Vector.<Vector.<Function>> = new <Vector.<Function>>[
		new <Function>[ encodeNone,            encodeSub,            encodeUp,            encodeAverage,            encodePaeth            ],
		new <Function>[ encodeNoneTransparent, encodeSubTransparent, encodeUpTransparent, encodeAverageTransparent, encodePaethTransparent ]
	];
	
	private static function encodeNoneTransparent(image:BitmapData, palette:IPalette):void {

		var width:int = image.width;
		var height:int = image.height;
		
		var hash:Object = palette.getHash();
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		
		if ( hash ) {
			
			do {
				si8( 0, i++ ); // NONE
				x = 0;
				do {
					si8( hash[ image.getPixel32( x, y ) ], i++ );
				} while ( ++x < width );
			} while ( ++y < height );

		} else {
		
			do {
				si8( 0, i++ ); // NONE
				x = 0;
				do {
					si8( palette.getIndexByColor( image.getPixel32( x, y ) ), i++ );
				} while ( ++x < width );
			} while ( ++y < height );

		}

	}
	
	private static function encodeSubTransparent(image:BitmapData, palette:IPalette):void {

		var width:int = image.width;
		var height:int = image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		var c0:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		
		if ( hash ) {
	
			do {
				si8( 1, i++ ); // SUB
				c0 = 0;
				x = 0;
				do {
					c = hash[ image.getPixel32( x, y ) ];
					si8( c - c0, i++ );
					c0 = c;
				} while ( ++x < width );
			} while ( ++y < height );

		} else {
			
			do {
				si8( 1, i++ ); // SUB
				c0 = 0;
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel32( x, y ) );
					si8( c - c0, i++ );
					c0 = c;
				} while ( ++x < width );
			} while ( ++y < height );

		}

	}
	
	private static function encodeUpTransparent(image:BitmapData, palette:IPalette):void {

		var width:int = image.width;
		var height:int = image.height;
		
		var len:uint = image.width * image.height + image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		var j:int = 0;
		
		if ( hash ) {

			do {
				j = len;
				si8( 2, i++ ); // UP
				x = 0;
				do {
					c = hash[ image.getPixel32( x, y ) ];
					si8( c - li8( j ), i++ );
					si8( c, j++ );
				} while ( ++x < width );
			} while ( ++y < height );

		} else {
			
			do {
				j = len;
				si8( 2, i++ ); // UP
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel32( x, y ) );
					si8( c - li8( j ), i++ );
					si8( c, j++ );
				} while ( ++x < width );
			} while ( ++y < height );

		}

	}
	
	private static function encodeAverageTransparent(image:BitmapData, palette:IPalette):void {

		var width:int = image.width;
		var height:int = image.height;
		
		var len:uint = image.width * image.height + image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		var c0:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		var j:int = 0;
		
		if ( hash ) {

			do {
				j = len;
				si8( 3, i++ ); // AVERAGE
				c0 = 0;
				x = 0;
				do {
					c = hash[ image.getPixel32( x, y ) ];
					si8( c - ( ( c0 + li8( j ) ) >>> 1 ), i++ );
					c0 = c;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );

		} else {
			
			do {
				j = len;
				si8( 3, i++ ); // AVERAGE
				c0 = 0;
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel32( x, y ) );
					si8( c - ( ( c0 + li8( j ) ) >>> 1 ), i++ );
					c0 = c;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );

		}

	}
	
	private static function encodePaethTransparent(image:BitmapData, palette:IPalette):void {

		var width:int = image.width;
		var height:int = image.height;
		
		var len:uint = image.width * image.height + image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		var c0:int = 0;
		var c1:int = 0;
		var c2:int = 0;
		
		var p:int = 0;
		var pa:int = 0;
		var pb:int = 0;
		var pc:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		var j:int = 0;
		
		if ( hash ) {
			
			do {
				j = len;
				si8( 3, i++ ); // PAETH
				c0 = 0;
				c2 = 0;
				x = 0;
				do {
					c = hash[ image.getPixel32( x, y ) ];
					c1 = li8( j );
					p = c0 + c1 - c2;
					pa = p - c0; if ( pa < 0 ) pa = -pa;
					pb = p - c1; if ( pb < 0 ) pb = -pb;
					pc = p - c2; if ( pc < 0 ) pc = -pc;
					if ( pa <= pb && pa <= pc ) p = c0;
					else if ( pb <= pc )		p = c1;
					else						p = c2;
					si8( c - p, i++ );
					c0 = c;
					c2 = c1;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );

		} else {
			
			do {
				j = len;
				si8( 3, i++ ); // PAETH
				c0 = 0;
				c2 = 0;
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel32( x, y ) );
					c1 = li8( j );
					p = c0 + c1 - c2;
					pa = p - c0; if ( pa < 0 ) pa = -pa;
					pb = p - c1; if ( pb < 0 ) pb = -pb;
					pc = p - c2; if ( pc < 0 ) pc = -pc;
					if ( pa <= pb && pa <= pc ) p = c0;
					else if ( pb <= pc )		p = c1;
					else						p = c2;
					si8( c - p, i++ );
					c0 = c;
					c2 = c1;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );

		}

	}
	
	private static function encodeNone(image:BitmapData, palette:IPalette):void {
		
		var width:int = image.width;
		var height:int = image.height;
		
		var hash:Object = palette.getHash();
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		
		if ( hash ) {
			
			do {
				si8( 0, i++ ); // NONE
				x = 0;
				do {
					si8( hash[ image.getPixel( x, y ) ], i++ );
				} while ( ++x < width );
			} while ( ++y < height );
			
		} else {
			
			do {
				si8( 0, i++ ); // NONE
				x = 0;
				do {
					si8( palette.getIndexByColor( image.getPixel( x, y ) ), i++ );
				} while ( ++x < width );
			} while ( ++y < height );
			
		}
		
	}
	
	private static function encodeSub(image:BitmapData, palette:IPalette):void {
		
		var width:int = image.width;
		var height:int = image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		var c0:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		
		if ( hash ) {
			
			do {
				si8( 1, i++ ); // SUB
				c0 = 0;
				x = 0;
				do {
					c = hash[ image.getPixel( x, y ) ];
					si8( c - c0, i++ );
					c0 = c;
				} while ( ++x < width );
			} while ( ++y < height );
			
		} else {
			
			do {
				si8( 1, i++ ); // SUB
				c0 = 0;
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel( x, y ) );
					si8( c - c0, i++ );
					c0 = c;
				} while ( ++x < width );
			} while ( ++y < height );
			
		}
		
	}
	
	private static function encodeUp(image:BitmapData, palette:IPalette):void {
		
		var width:int = image.width;
		var height:int = image.height;
		
		var len:uint = image.width * image.height + image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		var j:int = 0;
		
		if ( hash ) {
			
			do {
				j = len;
				si8( 2, i++ ); // UP
				x = 0;
				do {
					c = hash[ image.getPixel( x, y ) ];
					si8( c - li8( j ), i++ );
					si8( c, j++ );
				} while ( ++x < width );
			} while ( ++y < height );
			
		} else {
			
			do {
				j = len;
				si8( 2, i++ ); // UP
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel( x, y ) );
					si8( c - li8( j ), i++ );
					si8( c, j++ );
				} while ( ++x < width );
			} while ( ++y < height );
			
		}
		
	}
	
	private static function encodeAverage(image:BitmapData, palette:IPalette):void {
		
		var width:int = image.width;
		var height:int = image.height;
		
		var len:uint = image.width * image.height + image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		var c0:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		var j:int = 0;
		
		if ( hash ) {
			
			do {
				j = len;
				si8( 3, i++ ); // AVERAGE
				c0 = 0;
				x = 0;
				do {
					c = hash[ image.getPixel( x, y ) ];
					si8( c - ( ( c0 + li8( j ) ) >>> 1 ), i++ );
					c0 = c;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );
			
		} else {
			
			do {
				j = len;
				si8( 3, i++ ); // AVERAGE
				c0 = 0;
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel( x, y ) );
					si8( c - ( ( c0 + li8( j ) ) >>> 1 ), i++ );
					c0 = c;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );
			
		}
		
	}
	
	private static function encodePaeth(image:BitmapData, palette:IPalette):void {
		
		var width:int = image.width;
		var height:int = image.height;
		
		var len:uint = image.width * image.height + image.height;
		
		var hash:Object = palette.getHash();
		
		var c:int = 0;
		var c0:int = 0;
		var c1:int = 0;
		var c2:int = 0;
		
		var p:int = 0;
		var pa:int = 0;
		var pb:int = 0;
		var pc:int = 0;
		
		var x:int = 0;
		var y:int = 0;
		
		var i:int = 0;
		var j:int = 0;
		
		if ( hash ) {
			
			do {
				j = len;
				si8( 3, i++ ); // PAETH
				c0 = 0;
				c2 = 0;
				x = 0;
				do {
					c = hash[ image.getPixel( x, y ) ];
					c1 = li8( j );
					p = c0 + c1 - c2;
					pa = p - c0; if ( pa < 0 ) pa = -pa;
					pb = p - c1; if ( pb < 0 ) pb = -pb;
					pc = p - c2; if ( pc < 0 ) pc = -pc;
					if ( pa <= pb && pa <= pc ) p = c0;
					else if ( pb <= pc )		p = c1;
					else						p = c2;
					si8( c - p, i++ );
					c0 = c;
					c2 = c1;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );
			
		} else {
			
			do {
				j = len;
				si8( 3, i++ ); // PAETH
				c0 = 0;
				c2 = 0;
				x = 0;
				do {
					c = palette.getIndexByColor( image.getPixel( x, y ) );
					c1 = li8( j );
					p = c0 + c1 - c2;
					pa = p - c0; if ( pa < 0 ) pa = -pa;
					pb = p - c1; if ( pb < 0 ) pb = -pb;
					pc = p - c2; if ( pc < 0 ) pc = -pc;
					if ( pa <= pb && pa <= pc ) p = c0;
					else if ( pb <= pc )		p = c1;
					else						p = c2;
					si8( c - p, i++ );
					c0 = c;
					c2 = c1;
					si8( j++, c );
				} while ( ++x < width );
			} while ( ++y < height );
			
		}
		
	}
	
}