///|
#cfg(target="native")
priv suberror QuicFrameError {
  QuicFrameTruncated
  QuicFrameUnsupported
  QuicCryptoOutOfOrder
} derive(Debug, ToJson)

///|
#cfg(target="native")
let quic_frame_padding : Int = 0x00

///|
#cfg(target="native")
let quic_frame_ping : Int = 0x01

///|
#cfg(target="native")
let quic_frame_ack : Int = 0x02

///|
#cfg(target="native")
let quic_frame_crypto : Int = 0x06

///|
#cfg(target="native")
let quic_frame_stream_base : Int = 0x08

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicCryptoFrame {
  offset : Int
  data : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicAckFrame {
  largest_acknowledged : Int
  ack_delay : Int
  first_ack_range : Int
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicStreamFrame {
  stream_id : Int
  offset : Int
  fin : Bool
  data : Bytes
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_encode_padding(length : Int) -> Bytes raise {
  guard length >= 0 else { raise QuicFrameUnsupported }
  let out = Buffer()
  for _ in 0..<length {
    out.write_byte(quic_frame_padding.to_byte())
  }
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_encode_ping() -> Bytes {
  let out = Buffer()
  out.write_byte(quic_frame_ping.to_byte())
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_encode_ack(
  largest_acknowledged : Int,
  ack_delay : Int,
  first_ack_range : Int,
) -> Bytes raise {
  let out = Buffer()
  quic_write_varint(out, quic_frame_ack)
  quic_write_varint(out, largest_acknowledged)
  quic_write_varint(out, ack_delay)
  quic_write_varint(out, 0)
  quic_write_varint(out, first_ack_range)
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_decode_ack(data : Bytes, offset : Int) -> (QuicAckFrame, Int) raise {
  let (frame_type, pos) = quic_read_varint(data, offset)
  guard frame_type == quic_frame_ack else { raise QuicFrameUnsupported }
  let (largest_acknowledged, pos) = quic_read_varint(data, pos)
  let (ack_delay, pos) = quic_read_varint(data, pos)
  let (range_count, pos) = quic_read_varint(data, pos)
  let (first_ack_range, first_ack_range_end) = quic_read_varint(data, pos)
  let mut pos = first_ack_range_end
  for _ in 0..<range_count {
    let (_, gap_end) = quic_read_varint(data, pos)
    let (_, range_end) = quic_read_varint(data, gap_end)
    pos = range_end
  }
  ({ largest_acknowledged, ack_delay, first_ack_range, }, pos)
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_encode_crypto_frame(offset : Int, data : Bytes) -> Bytes raise {
  let out = Buffer()
  quic_write_varint(out, quic_frame_crypto)
  quic_write_varint(out, offset)
  quic_write_varint(out, data.length())
  out.write_bytes(data)
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_decode_crypto_frame(
  data : Bytes,
  offset : Int,
) -> (QuicCryptoFrame, Int) raise {
  let (frame_type, pos) = quic_read_varint(data, offset)
  guard frame_type == quic_frame_crypto else { raise QuicFrameUnsupported }
  let (crypto_offset, pos) = quic_read_varint(data, pos)
  let (len, pos) = quic_read_varint(data, pos)
  guard pos + len <= data.length() else { raise QuicFrameTruncated }
  (
    { offset: crypto_offset, data: quic_copy_slice(data, pos, pos + len), },
    pos + len,
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_encode_stream_frame(
  stream_id : Int,
  offset : Int,
  fin : Bool,
  data : Bytes,
) -> Bytes raise {
  let out = Buffer()
  let mut frame_type = quic_frame_stream_base | 0x02
  if offset > 0 {
    frame_type = frame_type | 0x04
  }
  if fin {
    frame_type = frame_type | 0x01
  }
  quic_write_varint(out, frame_type)
  quic_write_varint(out, stream_id)
  if offset > 0 {
    quic_write_varint(out, offset)
  }
  quic_write_varint(out, data.length())
  out.write_bytes(data)
  out.contents()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_decode_stream_frame(
  data : Bytes,
  offset : Int,
) -> (QuicStreamFrame, Int) raise {
  let (frame_type, pos) = quic_read_varint(data, offset)
  guard (frame_type & 0xf8) == quic_frame_stream_base else {
    raise QuicFrameUnsupported
  }
  let has_offset = (frame_type & 0x04) != 0
  let has_length = (frame_type & 0x02) != 0
  let fin = (frame_type & 0x01) != 0
  let (stream_id, pos) = quic_read_varint(data, pos)
  let (stream_offset, pos) = if has_offset {
    quic_read_varint(data, pos)
  } else {
    (0, pos)
  }
  let (len, pos) = if has_length {
    quic_read_varint(data, pos)
  } else {
    (data.length() - pos, pos)
  }
  guard pos + len <= data.length() else { raise QuicFrameTruncated }
  (
    {
      stream_id,
      offset: stream_offset,
      fin,
      data: quic_copy_slice(data, pos, pos + len),
    },
    pos + len,
  )
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_collect_crypto_data(payload : Bytes) -> Bytes raise {
  quic_merge_crypto_data([payload])
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_merge_crypto_data(payloads : Array[Bytes]) -> Bytes raise {
  let fragments = []
  let mut total_length = 0
  for payload in payloads {
    for offset = 0; offset < payload.length(); {
      let (frame_type, _) = quic_read_varint(payload, offset)
      if frame_type == quic_frame_padding {
        continue offset + 1
      } else if frame_type == quic_frame_ping {
        continue offset + 1
      } else if frame_type == quic_frame_ack {
        let (_, next) = quic_decode_ack(payload, offset)
        continue next
      } else if frame_type == quic_frame_crypto {
        let (frame, next) = quic_decode_crypto_frame(payload, offset)
        fragments.push(frame)
        let end = frame.offset + frame.data.length()
        if end > total_length {
          total_length = end
        }
        continue next
      } else {
        raise QuicFrameUnsupported
      }
    }
  }
  if fragments.length() == 0 {
    return b""
  }
  let out = FixedArray::make(total_length, b'\x00')
  let filled = FixedArray::make(total_length, false)
  for fragment in fragments {
    for i in 0..<fragment.data.length() {
      let pos = fragment.offset + i
      out[pos] = fragment.data[i]
      filled[pos] = true
    }
  }
  for value in filled {
    guard value else { raise QuicCryptoOutOfOrder }
  }
  out.unsafe_reinterpret_as_bytes()
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn quic_collect_stream_data(payload : Bytes, stream_id : Int) -> Bytes raise {
  let out = Buffer()
  for offset = 0; offset < payload.length(); {
    let (frame_type, _) = quic_read_varint(payload, offset)
    if frame_type == quic_frame_padding {
      continue offset + 1
    } else if frame_type == quic_frame_ping {
      continue offset + 1
    } else if frame_type == quic_frame_ack {
      let (_, next) = quic_decode_ack(payload, offset)
      continue next
    } else if (frame_type & 0xf8) == quic_frame_stream_base {
      let (frame, next) = quic_decode_stream_frame(payload, offset)
      if frame.stream_id == stream_id {
        guard frame.offset == out.length() else { raise QuicCryptoOutOfOrder }
        out.write_bytes(frame.data)
      }
      continue next
    } else {
      raise QuicFrameUnsupported
    }
  }
  out.contents()
}
