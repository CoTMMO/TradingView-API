//+------------------------------------------------------------------+
//|                                             PineIndicator.mqh     |
//+------------------------------------------------------------------+

// Enum for input types (equivalent to JavaScript string literals)
enum ENUM_INPUT_TYPE {
   INPUT_TYPE_TEXT,
   INPUT_TYPE_SOURCE,
   INPUT_TYPE_INTEGER,
   INPUT_TYPE_FLOAT,
   INPUT_TYPE_RESOLUTION,
   INPUT_TYPE_BOOL,
   INPUT_TYPE_COLOR
};

// IndicatorType enum
enum ENUM_INDICATOR_TYPE {
   INDICATOR_TYPE_SCRIPT,      // Script@tv-scripting-101!
   INDICATOR_TYPE_STRATEGY     // StrategyScript@tv-scripting-101!
};

// Structure for indicator input (equivalent to IndicatorInput typedef)
struct IndicatorInput {
   string            name;           // Input name
   string            inline_name;    // Input inline name
   string            internalID;     // Input internal ID
   string            tooltip;        // Input tooltip
   ENUM_INPUT_TYPE   type;           // Input type
   string            value;          // Input default value (as string for flexibility)
   bool              isHidden;       // If the input is hidden
   bool              isFake;         // If the input is fake
   string            options[];      // Input options if the input is a select
};

// Key-value pair for inputs dictionary
struct InputPair {
   string         key;
   IndicatorInput value;
};

// Key-value pair for plots dictionary
struct PlotPair {
   string key;
   string value;
};

//+------------------------------------------------------------------+
//| PineIndicator class                                              |
//+------------------------------------------------------------------+
class PineIndicator {
private:
   string               m_pineId;
   string               m_pineVersion;
   string               m_description;
   string               m_shortDescription;
   InputPair            m_inputs[];
   PlotPair             m_plots[];
   string               m_script;
   ENUM_INDICATOR_TYPE  m_type;
   
   // Helper method to find input index by key
   int FindInputIndex(const string key) {
      for(int i = 0; i < ArraySize(m_inputs); i++) {
         if(m_inputs[i].key == key || 
            m_inputs[i].key == "in_" + key ||
            m_inputs[i].value.inline_name == key ||
            m_inputs[i].value.internalID == key) {
            return i;
         }
      }
      return -1;
   }
   
   // Helper method to validate input value against type
   bool ValidateValueType(const IndicatorInput &input, const string value) {
      switch(input.type) {
         case INPUT_TYPE_BOOL:
            return value == "true" || value == "false";
            
         case INPUT_TYPE_INTEGER:
            // Check if value is an integer
            {
               int dummy;
               return StringToInteger(value, dummy);
            }
            
         case INPUT_TYPE_FLOAT:
            // Check if value is a number
            {
               double dummy;
               return StringToDouble(value, dummy);
            }
            
         // Other types don't need strict validation in this implementation
         default:
            return true;
      }
   }
   
public:
   // Constructor
   PineIndicator() {
      m_type = INDICATOR_TYPE_SCRIPT;
   }
   
   // Constructor with parameters (equivalent to JS constructor)
   PineIndicator(
      const string pineId,
      const string pineVersion,
      const string description,
      const string shortDescription,
      const string script
   ) {
      m_pineId = pineId;
      m_pineVersion = pineVersion;
      m_description = description;
      m_shortDescription = shortDescription;
      m_script = script;
      m_type = INDICATOR_TYPE_SCRIPT;
   }
   
   // Getters (equivalent to JS getters)
   string GetPineId() const { return m_pineId; }
   string GetPineVersion() const { return m_pineVersion; }
   string GetDescription() const { return m_description; }
   string GetShortDescription() const { return m_shortDescription; }
   string GetScript() const { return m_script; }
   
   // Get type as string
   string GetTypeAsString() const {
      if(m_type == INDICATOR_TYPE_SCRIPT) return "Script@tv-scripting-101!";
      return "StrategyScript@tv-scripting-101!";
   }
   
   // Get type as enum
   ENUM_INDICATOR_TYPE GetType() const { return m_type; }
   
   // Set the indicator type
   void SetType(ENUM_INDICATOR_TYPE type = INDICATOR_TYPE_SCRIPT) {
      m_type = type;
   }
   
   // Add input
   bool AddInput(const string key, const IndicatorInput &input) {
      int size = ArraySize(m_inputs);
      ArrayResize(m_inputs, size + 1);
      m_inputs[size].key = key;
      m_inputs[size].value = input;
      return true;
   }
   
   // Add plot
   bool AddPlot(const string key, const string value) {
      int size = ArraySize(m_plots);
      ArrayResize(m_plots, size + 1);
      m_plots[size].key = key;
      m_plots[size].value = value;
      return true;
   }
   
   // Get input
   bool GetInput(const string key, IndicatorInput &input) {
      int index = FindInputIndex(key);
      if(index < 0) return false;
      
      input = m_inputs[index].value;
      return true;
   }
   
   // Get plot
   bool GetPlot(const string key, string &value) {
      for(int i = 0; i < ArraySize(m_plots); i++) {
         if(m_plots[i].key == key) {
            value = m_plots[i].value;
            return true;
         }
      }
      return false;
   }
   
   // Set an option (equivalent to JS setOption)
   bool SetOption(const string key, const string value) {
      int index = FindInputIndex(key);
      if(index < 0) {
         Print("Input '", key, "' not found.");
         return false;
      }
      
      IndicatorInput &input = m_inputs[index].value;
      
      // Validate value type
      if(!ValidateValueType(input, value)) {
         Print("Input '", input.name, "' (", m_inputs[index].key, ") has invalid type!");
         return false;
      }
      
      // Check options
      if(ArraySize(input.options) > 0) {
         bool found = false;
         for(int i = 0; i < ArraySize(input.options); i++) {
            if(input.options[i] == value) {
               found = true;
               break;
            }
         }
         
         if(!found) {
            Print("Input '", input.name, "' (", m_inputs[index].key, ") must be one of the predefined options!");
            return false;
         }
      }
      
      // Set the value
      input.value = value;
      return true;
   }
};
