#!/usr/bin/python

import os, sys
import shutil
import json
from functools import reduce  # forward compatibility for Python 3
import operator

SCRIPT_NAME = sys.argv[0]

## Supporting Functions
def getFromDict(dataDict, mapList):
    return reduce(operator.getitem, mapList, dataDict)

def setInDict(dataDict, mapList, value):
    getFromDict(dataDict, mapList[:-1])[mapList[-1]] = value


def fetch_env_var_val(env_var_name):
    '''
    '''
    if env_var_name in os.environ:
        return(os.environ[env_var_name])
    else:
        print SCRIPT_NAME, ": Environment variable", env_var_name, "not found"
        return None

def get_intu_element_list(bootstrap_data_json, element_type_str, name_proto_str="Type_"):
    '''
    parses json structure from intu bootstrap.json config file and
    extracts list of element fields from top-level dict key matching "element_type_str"
    Inputs:
      bootstrap_data_json: json structure of bootstrap.json file (dict{list[dicts{}]})
      element_type_str: desired key of top-level json data to be parsed ex: "m_Agents"
      name_proto_str: 3rd-level key (varies by element type) to be returned as the "name"
        ex: name_proto_str="Type_" for agents; ="m_ServiceId" for serviceConfigs
    Returns: 
      list of element types (agent names, classifier names, serviceConfig Id's)
    '''
    if element_type_str in bootstrap_data_json:
       lst = bootstrap_data_json[element_type_str]
       return [lst[i][name_proto_str] for i in range(len(lst))]
    else:
       print(SCRIPT_NAME, ": Error: element", element_type_str, " not in boostrap.json data")
       return []

def set_intu_config_val(data, env_var):
    '''
    Read env_var input string, decompose, and find matching intu config parameter in json
      data dict
    Set intu config param to value pointed to by environment variable name
    See google spreadsheet doc for naming convention: 
      https://docs.google.com/spreadsheets/d/1J9RxQHpA0ZYXnvbDBzSFkyRsfA3vBhI9YRgxsxc0z6Q
    '''
    # Decompose environment variable name, get value
    tokens = env_var.split('_')[1:]   # first is prefix (not used)

    # Check for too-short/insufficient environment variable names
    if len(tokens) < 2:
       print (SCRIPT_NAME, ": warning: an apparent config environment variable was too short to be used:", 
           env_var)
    
    # Check for intu member variables in last position
    if len(tokens[-2]) == 1:                            # yep: "m_User", etc
	tokens[-2] = '_'.join([tokens[-2], tokens[-1]]) # rebuild variable
        tokens.pop()
    print ("tokens =", tokens)

    # Parse out env var bits    
    name = tokens[0]         # ConversationV1, SpeechToTextV1, etc           (literal)
    param = tokens[1]        # m_User, m_Password, WorkspaceKey, WorkspaceId (literal)
        
    # Get env var value
    val = os.environ[env_var]

#    # Test 
#    name = "PersonalityInsightsV1"
#    param = "m_Password"
    print("Testing with %s and %s" % (name, param))
    dmap = get_map_to_param(data, name, param, "")

    err = set_config_val(data, dmap, name, param, val)

    err = None

    return err
    
def set_type(val, typ):
    '''
    Sets the type of a value compatible with json format
     unicode string
     int
     float
    '''
    t = str(typ)
    print t
    if t.find("unicode") >= 0:
        return(unicode(str(val), "utf-8"))
    elif t.find("float") >= 0:
        return(float(val))
    elif t.find("int") >= 0:
        return(int(val))
    else:
        return val


def item_generator(json_input, lookup_key):
    path = []
    if isinstance(json_input, dict):
        for k, v in json_input.iteritems():
            if k == lookup_key:
                yield v
            else:
                for child_val in item_generator(v, lookup_key):
                    yield child_val
    elif isinstance(json_input, list):
        for item in json_input:
            for item_val in item_generator(item, lookup_key):
                yield item_val


def dict_generator(indict, pre=None):
    pre = pre[:] if pre else []
    if isinstance(indict, dict):
        for key, value in indict.items():
            if isinstance(value, dict):
                for d in dict_generator(value, [key] + pre):
                    yield d
            elif isinstance(value, list) or isinstance(value, tuple):
                for i,v in enumerate(value):   # added i to track list index
                    for d in dict_generator(v, [key, i] + pre):          
                        yield d
            else:
                yield pre + [key, value]
    else:
        yield indict


def set_config_val(data, dmap, name, param, value):
    '''
    '''
    # Get category names list
    categories = data.keys()
    print("categories: %s" % categories)
    
    indx = dmap.pop(0)             # the first list element is the position in 1st array
    category = dmap.pop(0)         # the first dict level (Agent, Service, etc)
    current_value = dmap.pop(-1)
#    current_param = dmap.pop(-1)   # this should match param
    if param != dmap[-1]:  
       print(SCRIPT_NAME, ": error:", current_param, "does not match", param)
    
    print("index=%s, curr_val=%s, curr_param=%s, param=%s, what's left=%s" % (indx, current_value, dmap[-1], param, dmap))

    print data[category][indx]
    setInDict(data[category][indx], dmap, value)
    print("Value set | %s=%s" % (dmap, value))

    err = 0

    
def set_classifier_config_val(data, name, var_name, value):
    '''
    '''
    classifier_names = get_intu_element_list(data, "m_Classifiers", "Type_")


def get_map_to_param(data, name, param, keyword=""):

    # Parse structure recursively
    di = dict_generator(data)

    # Eliminate single-value elements
    di = [d for d in di if isinstance(d, list)]
 
    # First pass: identify elements with name
    branches = [d for d in di if d[-1] == name]

    # Second pass: identify the param in adjacent element   
    for b in branches:
        ln = len(b)
        for d in di:
            if param in d and len(d) == ln and d[0:ln-2] == b[:ln-2]:
               print("found one!: d=%s, b=%s" % (d, b))
               return d


## Main
def main(args):
    print SCRIPT_NAME, ": Main()"

    # Check for and read Intu bootstrap file:
    bootstrap_file = fetch_env_var_val("INTU_BOOTSTRAP_FILE_PATH")
    if bootstrap_file == None:
        raise Exception("%s: Error: environment var not found." % SCRIPT_NAME)

    # Make a backup copy of the bootstrap.json file
    shutil.copy2(bootstrap_file, bootstrap_file+".bak")

    # Get environment variables having our prefix
    prefix = "WATSON"
    env_vars = []
    for env in os.environ:
        if env.startswith(prefix): 
            env_vars.append(env)
    
    # Read json bootstrap file, with intu config settings
    data = None
    with open(bootstrap_file, 'r') as infile:
        data = json.load(infile)

    # Set each environment variable value in our json structure (passed by ref)
    for env in env_vars:
        err = set_intu_config_val(data, env)

    # Write out new bootstrap.json file
    with open(bootstrap_file + "-test.json", 'w') as outfile:
         json.dump(data, outfile, indent=4, sort_keys=True)

    sys.exit(0)

if __name__ == '__main__':
    main(sys.argv)

