// Copyright 2016 The Tulsi Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa


// Models a node in the source filter picker.
final class SourcePathNode: UISelectableOutlineViewNode {
  dynamic var recursive: Bool {
    get {
      guard let entry = entry as? UISourcePath else { return false }
      return entry.recursive
    }

    set {
      guard let entry = entry as? UISourcePath else { return }
      entry.recursive = newValue

      // If this node is newly recursive, force hasRecursiveEnabledParent, otherwise have children
      // inherit this node's status.
      setChildrenHaveRecursiveParent(newValue || hasRecursiveEnabledParent)
    }
  }

  dynamic var hasRecursiveEnabledParent: Bool = false {
    willSet {
      // If this node is recursive its children will still have a recursive parent and there's no
      // need to update them.
      if recursive || newValue == hasRecursiveEnabledParent { return }
      setChildrenHaveRecursiveParent(newValue)
    }
  }

  func setChildrenHaveRecursiveParent(newValue: Bool) {
    for child in children as! [SourcePathNode] {
      child.hasRecursiveEnabledParent = newValue
    }
  }
}


// Controller for the view allowing users to select a subset of the source files to include in the
// generated Xcode project.
final class ConfigEditorSourceFilterViewController: NSViewController, WizardSubviewProtocol {
  dynamic var sourceFilterContentArray: [SourcePathNode] = []

  // MARK: - WizardSubviewProtocol

  weak var presentingWizardViewController: ConfigEditorWizardViewController? = nil

  func wizardSubviewWillActivateMovingForward() {
    let document = representedObject as! TulsiGeneratorConfigDocument
    sourceFilterContentArray = []
    document.updateSourcePaths(populateOutlineView)

    // TODO(abaire): Set when toggling selection instead.
    document.updateChangeCount(.ChangeDone)  // TODO(abaire): Implement undo functionality.
  }

  // MARK: - Private methods

  private func populateOutlineView(sourcePaths: [UISourcePath]) {
    // Decompose each rule and merge into a tree of subelements.
    let componentDelimiters = NSCharacterSet(charactersInString: "/:")
    let splitSourcePaths = sourcePaths.map() {
      $0.path.componentsSeparatedByCharactersInSet(componentDelimiters)
    }

    var recursiveNodes = [SourcePathNode]()

    let topNode = SourcePathNode(name: "")
    for var i = 0; i < splitSourcePaths.count; ++i {
      let label = splitSourcePaths[i]
      var node = topNode
      elementLoop: for element in label {
        if element == "" {
          continue
        }
        for child in node.children as! [SourcePathNode] {
          if child.name == element {
            node = child
            continue elementLoop
          }
        }
        let newNode = SourcePathNode(name: element)
        node.addChild(newNode)
        node = newNode
      }
      node.entry = sourcePaths[i]
      if node.recursive {
        recursiveNodes.append(node)
      }
    }

    // Patch up the recursive status now that the entire tree is constructed.
    for node in recursiveNodes {
      node.setChildrenHaveRecursiveParent(true)
    }

    sourceFilterContentArray = topNode.children as! [SourcePathNode]
  }
}