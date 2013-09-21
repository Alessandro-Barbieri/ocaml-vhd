(*
 * Copyright (C) 2011-2013 Citrix Inc
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)

let project_url = "http://github.com/djs55/ocaml-vhd"

open Common
open Cmdliner

(* Help sections common to all commands *)

let _common_options = "COMMON OPTIONS"
let help = [ 
 `S _common_options; 
 `P "These options are common to all commands.";
 `S "MORE HELP";
 `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command."; `Noblank;
 `S "BUGS"; `P (Printf.sprintf "Check bug reports at %s" project_url);
]

(* Options common to all commands *)
let common_options_t = 
  let docs = _common_options in 
  let debug = 
    let doc = "Give only debug output." in
    Arg.(value & flag & info ["debug"] ~docs ~doc) in
  let verb =
    let doc = "Give verbose output." in
    let verbose = true, Arg.info ["v"; "verbose"] ~docs ~doc in 
    Arg.(last & vflag_all [false] [verbose]) in 
  Term.(pure Common.make $ debug $ verb)

let get_cmd =
  let doc = "query vhd metadata" in
  let man = [
    `S "DESCRIPTION";
    `P "Look up a particular metadata property by name and print the value."
  ] @ help in
  let filename =
    let doc = Printf.sprintf "Path to the vhd file." in
    Arg.(value & pos 0 (some file) None & info [] ~doc) in
  let key =
    let doc = "Key to query" in
    Arg.(value & pos 1 (some string) None & info [] ~doc) in
  Term.(ret(pure Impl.get $ common_options_t $ filename $ key)),
  Term.info "get" ~sdocs:_common_options ~doc ~man

let info_cmd =
  let doc = "display general information about a vhd" in
  let man = [
    `S "DESCRIPTION";
    `P "Display general information about a vhd, including header and footer fields. This won't directly display block allocation tables or sector bitmaps.";
  ] @ help in
  let filename =
    let doc = Printf.sprintf "Path to the vhd file." in
    Arg.(value & pos 0 (some file) None & info [] ~doc) in
  Term.(ret(pure Impl.info $ common_options_t $ filename)),
  Term.info "info" ~sdocs:_common_options ~doc ~man

let create_cmd =
  let doc = "create a dynamic vhd" in
  let man = [
    `S "DESCRIPTION";
    `P "Create a dynamic vhd (i.e. one which may be sparse). A dynamic vhd may be self-contained or it may have a backing-file or 'parent'.";
  ] @ help in
  let filename =
    let doc = Printf.sprintf "Path to the vhd file to be created." in
    Arg.(value & pos 0 (some string) None & info [] ~doc) in
  let size =
    let doc = Printf.sprintf "Virtual size of the disk." in
    Arg.(value & opt (some string) None & info [ "size" ] ~doc) in
  let parent =
    let doc = Printf.sprintf "Parent image" in
    Arg.(value & opt (some file) None & info [ "parent" ] ~doc) in
  Term.(ret(pure Impl.create $ common_options_t $ filename $ size $ parent)),
  Term.info "create" ~sdocs:_common_options ~doc ~man

let check_cmd =
  let doc = "check the structure of a vhd file" in
  let man = [
    `S "DESCRIPTION";
    `P "Check the structure of a vhd file is valid, print any errors on the console.";
  ] @ help in
  let filename =
    let doc = Printf.sprintf "Path to the vhd to be checked." in
    Arg.(value & pos 0 (some file) None & info [] ~doc) in
  Term.(ret(pure Impl.check $ common_options_t $ filename)),
  Term.info "check" ~sdocs:_common_options ~doc ~man

let source =
  let doc = Printf.sprintf "The disk to be streamed" in
  Arg.(value & opt string "stdin:" & info [ "source" ] ~doc)

let source_protocol =
  let doc = "Transport protocol for the source data." in
  Arg.(value & opt (some string) None & info [ "source-protocol" ] ~doc)

let destination =
  let doc = "Destination for streamed data." in
  Arg.(value & opt string "stdout:" & info [ "destination" ] ~doc)

let destination_format =
  let doc = "Destination format" in
  Arg.(value & opt string "raw" & info [ "destination-format" ] ~doc)

let serve_cmd =
  let doc = "serve the contents of a disk" in
  let man = [
    `S "DESCRIPTION";
    `P "Allow the contents of a disk to be read or written over a network protocol";
    `P "EXAMPLES";
    `P " vhd-tool serve --source fd:5 --source-protocol=chunked --destination file:///foo.raw --destination-format raw";
  ] in
  Term.(ret(pure Impl.serve $ common_options_t $ source $ source_protocol $ destination $ destination_format)),
  Term.info "serve" ~sdocs:_common_options ~doc ~man

let stream_cmd =
  let doc = "stream the contents of a vhd disk" in
  let man = [
    `S "DESCRIPTION";
    `P "Read the contents of a virtual disk from a source using (format, protocol) and write it out to a destination using another (format, protocol). This command allows disks to be uploaded, downloaded and format-converted in a space-efficient manner.";
    `S "FORMATS";
    `P "The input format and the output format are specified separately: this allows easy format conversion during the streaming process. The following formats are defined:";
    `P "  raw: a single flat image";
    `P "  vhd: the Virtual Hard Disk format used in XenServer";
    `P "Note: the vhd format supports both self-contained single file images and also \"differencing disks\" containing only the differences between two disks. To input only the differences between two disks, specify the reference disk with the \"--relative-to\" argument.";
    `S "PROTOCOLS";
    `P "Protocols are the means by which a disk image in a particular format is written to a particular destination. The following protocols are supported:";
    `P "  nbd:     the Network Block Device protocol";
    `P "  chunked: the XenServer chunked disk upload protocol";
    `P "  none:    unencoded write";
    `P "  human:   human-readable description of the contents";
    `P "The default behaviour is to auto-detect based on the destination.";
    `S "SOURCES and DESTINATIONS";
    `P "The source describes where the disk data comes from. The destination describes where the disk data is written to. The following are defined:";
    `P "  stdin:";
    `P "    read from standard input (input only)";
    `P "  stdout:";
    `P "    write to standard output (destination only)";
    `P "  fd:5";
    `P "    read and write from file descriptor 5";
    `P "  <filename>";
    `P "    read from or write to the file <filename>";
    `P "  unix://<path>";
    `P "    connect to the Unix domain socket";
    `P "  tcp://server:port/path";
    `P "    to issue an HTTP PUT to server:port/path";
    `P "  tcp://host:port/";
    `P "    to connect to TCP port 'port' on host 'host'";
    `S "OTHER OPTIONS";
    `P "When transferring a raw format image onto a medium which is completely empty (i.e. full of zeroes) it is possible to optimise the transfer by avoiding writing empty blocks. The default behaviour is to write zeroes, which is always safe. If you know your media is empty then supply the '--prezeroed' argument.";
    `P "When running interactively, the --progress argument will cause a progress bar and summary statistics to be printed.";
    `S "NOTES";
    `P "Not all protocols can be used with all destinations. For example the NBD protocol needs the ability to read (responses) and write (requests); it therefore will not work with the stdout: destination";
    `S "EXAMPLES";
    `P "  $(tname) stream --source=foo.vhd --source-format=vhd --destination-format=raw --destination=http://user:password@xenserver/import_raw_vdi?vdi=<uuid>";
  ] @ help in
  let source_format =
    let doc = "Source format" in
    Arg.(value & opt string "raw" & info [ "source-format" ] ~doc) in
  let source =
    let doc = Printf.sprintf "The disk to be streamed" in
    Arg.(value & opt string "stdin:" & info [ "source" ] ~doc) in
  let relative_to =
    let doc = "Output only differences from the given reference disk" in
    Arg.(value & opt (some file) None & info [ "relative-to" ] ~doc) in
  let destination_protocol =
    let doc = "Transport protocol for the destination data." in
    Arg.(value & opt (some string) None & info [ "destination-protocol" ] ~doc) in
  let prezeroed =
    let doc = "Assume the destination is completely empty." in
    Arg.(value & flag & info [ "prezeroed" ] ~doc) in
  let progress =
    let doc = "Display a progress bar." in
    Arg.(value & flag & info ["progress"] ~doc) in
  Term.(ret(pure Impl.stream $ common_options_t $ source $ relative_to $ source_format $ destination_format $ destination $ source_protocol $ destination_protocol $ prezeroed $ progress)),
  Term.info "stream" ~sdocs:_common_options ~doc ~man


let default_cmd = 
  let doc = "manipulate virtual disks stored in vhd files" in 
  let man = help in
  Term.(ret (pure (fun _ -> `Help (`Pager, None)) $ common_options_t)),
  Term.info "vhd-tool" ~version:"1.0.0" ~sdocs:_common_options ~doc ~man
       
let cmds = [info_cmd; get_cmd; create_cmd; check_cmd; serve_cmd; stream_cmd]

let _ =
  match Term.eval_choice default_cmd cmds with 
  | `Error _ -> exit 1
  | _ -> exit 0
