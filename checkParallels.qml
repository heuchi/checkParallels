//==============================================
//  check for parallel 5ths/8ves v0.1
//
//  Copyright (C)2015 Jörn Eichler (heuchi) 
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//==============================================

import QtQuick 2.0
import QtQuick.Dialogs 1.1
import MuseScore 1.0

MuseScore {
      menuPath: "Plugins.Proof Reading.Check for parallel 5ths/8ves"
      description: "Check for parallel fifths and octaves.\nMarks consecutive fifths and octaves and also ascending hidden parallels."
      version: "0.1"

      property var colorFifth: "#ff6500";
      property var colorOctave: "#ff0050";
      property var colorHidden: "#a03500";

      property bool processAll: false;
      property bool errorChords: false;

      MessageDialog {
            id: msgResult
            title: "Result"
            text: "Not yet set"
            
            onAccepted: {
                  Qt.quit();
            }

            visible: false;
      }

      function sgn(x) {
            if (x > 0) return(1);
            else if (x == 0) return(0);
            else return(-1);
      }

      function markColor(note1, note2, color) {
            note1.color = color;
            note2.color = color;
      }

      function markText(note1, note2, msg, color, trck, tick) {
            markColor(note1, note2, color);
            var myText = newElement(Element.STAFF_TEXT);
            myText.text = msg;
            //myText.pos.x = 0;
            myText.pos.y = 1;
            
            var cursor = curScore.newCursor();
            cursor.rewind(0);
            cursor.track = trck;
            while (cursor.tick < tick) {
                  cursor.next();
            }
            cursor.add(myText);
      }            

      onRun: {
            console.log("start")
            if (typeof curScore == 'undefined' || curScore == null) {
                  console.log("no score found");
                  Qt.quit();
            }

            // find selection
            var startStaff;
            var endStaff;
            var endTick;

            var cursor = curScore.newCursor();
            cursor.rewind(1);
            if (!cursor.segment) {
                  // no selection
                  console.log("no selection: processing whole score");
                  processAll = true;
                  startStaff = 0;
                  endStaff = curScore.nstaves;
            } else {
                  startStaff = cursor.staffIdx;
                  cursor.rewind(2);
                  endStaff = cursor.staffIdx+1;
                  endTick = cursor.tick;
                  if(endTick == 0) {
                        // selection includes end of score
                        // calculate tick from last score segment
                        endTick = curScore.lastSegment.tick + 1;
                  }
                  cursor.rewind(1);
                  console.log("Selection is: Staves("+startStaff+"-"+endStaff+") Ticks("+cursor.tick+"-"+endTick+")");
            }      

            // initialize data structure

            var changed = [];
            var curNote = [];
            var prevNote = [];
            var curRest = [];
            var prevRest = [];
            var curTick = [];
            var prevTick = [];

            var foundParallels = 0;

            var track;

            var startTrack = startStaff * 4;
            var endTrack = endStaff * 4;

            for (track = startTrack; track < endTrack; track++) {
                  curRest[track] = true;
                  prevRest[track] = true;
                  changed[track] = false;
                  curNote[track] = 0;
                  prevNote[track] = 0;
                  curTick[track] = 0;
                  prevTick[track] = 0;
            }

            // go through all staves/voices simultaneously

            if(processAll) {
                  cursor.track = 0;
                  cursor.rewind(0);
            } else {
                  cursor.rewind(1);
            }

            var segment = cursor.segment;

            while (segment && (processAll || segment.tick < endTick)) {
                  // Pass 1: read notes
                  for (track = startTrack; track < endTrack; track++) {
                        if (segment.elementAt(track)) {
                              if (segment.elementAt(track).type == Element.CHORD) {
                                    // we ignore grace notes for now
                                    var notes = segment.elementAt(track).notes;

                                    if (notes.length > 1) {
                                          console.log("found chord with more than one note!");
                                          errorChords = true;
                                    }

                                    var note = notes[notes.length-1];

                                    prevTick[track]=curTick[track];
                                    prevRest[track]=curRest[track];
                                    prevNote[track]=curNote[track];
                                    curRest[track]=false;
                                    curNote[track]=note;
                                    curTick[track]=segment.tick;
                                    changed[track]=true;
                              } else if (segment.elementAt(track).type == Element.REST) {
                                    if (!curRest[track]) {
                                          // was note
                                          prevRest[track]=curRest[track];
                                          prevNote[track]=curNote[track];
                                          curRest[track]=true;
                                          changed[track]=false; // no need to check against a rest
                                    }
                              } else {
                                    changed[track] = false;
                              }
                        } else {
                              changed[track] = false;
                        }
                  }
                  // Pass 2: find paralleles
                  for (track=startTrack; track < endTrack; track++) {
                        var i;
                        // compare to other tracks
                        if (changed[track] && (!prevRest[track])) {
                              var dir1 = sgn(curNote[track].pitch - prevNote[track].pitch);
                              if (dir1 == 0) continue; // voice didn't move
                              for (i=track+1; i < endTrack; i++) {
                                    if (changed[i] && (!prevRest[i])) {
                                          var dir2 = sgn(curNote[i].pitch-prevNote[i].pitch);
                                          if (dir1 == dir2) { // both voices moving in the same direction
                                                var cint = curNote[track].pitch - curNote[i].pitch;
                                                var pint = prevNote[track].pitch-prevNote[i].pitch;
                                                // test for 5th
                                                if (Math.abs(cint%12) == 7) {
                                                      // test for open parallel
                                                      if (cint == pint) {
                                                            foundParallels++;
                                                            console.log ("P5:"+cint+", "+pint);
                                                            markText(prevNote[track],prevNote[i],"parallel 5th",
                                                                  colorFifth,track,prevTick[track]);
                                                            markColor(curNote[track],curNote[i],colorFifth);
                                                      } else if (dir1 == 1 && Math.abs(pint) < Math.abs(cint)) {
                                                            // hidden parallel (only when moving up)
                                                            foundParallels++;
                                                            console.log ("H5:"+cint+", "+pint);
                                                            markText(prevNote[track],prevNote[i],"hidden 5th",
                                                                  colorHidden,track,prevTick[track]);
                                                            markColor(curNote[track],curNote[i],colorHidden);
                                                      }                                                
                                                }
                                                // test for 8th
                                                if (Math.abs(cint%12) == 0) {
                                                      // test for open parallel
                                                      if (cint == pint) {
                                                            foundParallels++;
                                                            console.log ("P8:"+cint+", "+pint+"Tracks "+track+","+i+" Tick="+segment.tick);
                                                            markText(prevNote[track],prevNote[i],"parallel 8th",
                                                                  colorOctave,track,prevTick[track]);
                                                            markColor(curNote[track],curNote[i],colorOctave);
                                                      } else if (dir1 == 1 && Math.abs(pint) < Math.abs(cint)) {
                                                            // hidden parallel (only when moving up)
                                                            foundParallels++;
                                                            console.log ("H8:"+cint+", "+pint);
                                                            markText(prevNote[track],prevNote[i],"hidden 8th",
                                                                  colorHidden,track,prevTick[track]);
                                                            markColor(curNote[track],curNote[i],colorHidden);
                                                      }                                                
                                                }
                                          }
                                    }
                              }
                        }
                  }
                  segment = segment.next;
            }

            // set result dialog

            if (foundParallels == 0) {
                  msgResult.text = "No parallels found!\n";
            } else if (foundParallels == 1) {
                  msgResult.text = "One parallel found!\n";
            } else {
                  msgResult.text = foundParallels + " parallels found!\n";
            }

            if (errorChords) {
                  msgResult.text = msgResult.text + 
                  "\nError: Found Chords!\nOnly the top note of each voice is used in this plugin!\n";
            }

            console.log("finished");
            msgResult.visible = true;
            //Qt.quit() // dialog will call Qt.quit()
      }
}
